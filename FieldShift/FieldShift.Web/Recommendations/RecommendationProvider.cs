using System.Globalization;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Calendar;
using FieldShift.Prediction.Engine.Explanations;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using Microsoft.Extensions.Caching.Memory;
using Polly;
using Polly.Retry;
using Polly.Timeout;

namespace FieldShift.Web.Recommendations;

public sealed record EngineData(CropKnowledgeBase KnowledgeBase, EngineSettings Settings);

public sealed class RecommendationProvider(
    EngineData engine,
    SoilGridsClient soilClient,
    NasaPowerClient nasa,
    IMemoryCache cache,
    TimeProvider time,
    ILogger<RecommendationProvider> logger)
{
    public const string Balanced = "balanced";
    public const string SoilHealth = "soil_health";
    public const string SafeHarvest = "safe_harvest";

    private static readonly (string Goal, string Strategy)[] Goals =
    [
        (Balanced, "balanced"),
        (SoilHealth, "soilHealth"),
        (SafeHarvest, "survival"),
    ];

    public static bool IsGoal(string goal) => Goals.Any(g => g.Goal == goal);

    private const int FirstClimateYear = 2014;
    private static readonly string[] DailyParameters = ["T2M_MIN", "T2M_MAX", "PRECTOTCORR"];

    // Typical Polish topsoil, used only for values SoilGrids did not give. Reported as "soil_unavailable", "soil_no_data" or "soil_partial".
    private const double DefaultSand = 50, DefaultClay = 15, DefaultSilt = 35, DefaultPh = 6.0, DefaultSoc = 12;

    // SoilGrids times out at random (a stalled connection, not a slow answer: the 5-property query takes ~7 s). So each
    // attempt is capped at 20 s and retried with growing, jittered delays, all within 75 s. Only this light query:
    // the full field-profile query keeps the longer budget of the HTTP client.
    private static readonly TimeSpan SoilAttemptTimeout = TimeSpan.FromSeconds(20);
    private static readonly TimeSpan SoilTotalTimeout = TimeSpan.FromSeconds(75);

    private ResiliencePipeline SoilPipeline => field ??= new ResiliencePipelineBuilder()
        .AddTimeout(SoilTotalTimeout)
        .AddRetry(new RetryStrategyOptions
        {
            MaxRetryAttempts = 3,
            Delay = TimeSpan.FromSeconds(1),
            BackoffType = DelayBackoffType.Exponential,
            UseJitter = true,
            ShouldHandle = new PredicateBuilder()
                .Handle<TimeoutRejectedException>()
                .Handle<HttpRequestException>()
                .Handle<IOException>()
                .Handle<FormatException>(),
            OnRetry = args =>
            {
                logger.LogWarning("SoilGrids attempt {Attempt} failed ({Error}); retrying in {Delay:0.#} s",
                    args.AttemptNumber + 1, args.Outcome.Exception?.GetType().Name, args.RetryDelay.TotalSeconds);
                return default;
            },
        })
        .AddTimeout(SoilAttemptTimeout)
        .Build();

    // The search uses all cores for about a second; do not let many requests pile onto the CPU.
    private static readonly SemaphoreSlim Gate = new(2);

    public async Task<RecommendationResponse> RecommendAsync(
        RecommendationRequest request, double lat, double lon, string goal, CancellationToken ct)
    {
        var kb = engine.KnowledgeBase;
        var warnings = new List<RecommendationWarning>();
        var inputs = new List<RecommendationInput> { new() { Key = "climate", Origin = "satellite" } };

        var roundedLat = Math.Round(lat, 2, MidpointRounding.AwayFromZero);
        var roundedLon = Math.Round(lon, 2, MidpointRounding.AwayFromZero);

        var soilTask = GetSoilAsync(roundedLat, roundedLon, ct);
        var climateTask = GetClimateAsync(roundedLat, roundedLon, ct);
        await Task.WhenAll(soilTask, climateTask);

        var soil = BuildSoil(soilTask.Result, roundedLat, roundedLon, warnings);
        inputs.Add(new RecommendationInput { Key = "soil", Origin = soil.Estimated ? "estimated" : "model" });

        var history = BuildHistory(request.PastCrops ?? [], warnings);
        if (history.Count > 0)
        {
            inputs.Add(new RecommendationInput { Key = "history", Origin = "user_answer" });
        }

        var excluded = (request.ExcludedCrops ?? []).Select(CropIdMap.ToEngine).OfType<string>()
            .Distinct().Select(CropId.From).ToList();

        var farmer = new FarmerInputs
        {
            HasLivestockOrManure = request.HasLivestock ?? false,
            HasIrrigation = request.HasIrrigation ?? false,
            ExcludedCrops = excluded,
            SoilTest = request.SoilPhKCl is { } ph
                ? new SoilTest { SampledOn = DateOnly.FromDateTime(time.GetUtcNow().UtcDateTime), PhKCl = ph }
                : null,
        };
        if (request.HasLivestock is not null || request.HasIrrigation is not null
            || request.SoilPhKCl is not null || excluded.Count > 0)
        {
            inputs.Add(new RecommendationInput { Key = "farmer", Origin = "user_answer" });
        }

        var plot = new Plot
        {
            Location = new GeoLocation(roundedLat, roundedLon, 0),
            Soil = soil.Value,
            Climate = climateTask.Result,
            Farmer = farmer,
            History = history,
        };

        await Gate.WaitAsync(ct);
        RecommendationResult result;
        try
        {
            result = await Task.Run(
                () => RecommendationService.Recommend(plot, kb, engine.Settings, timeProvider: time, ct: ct), ct);
        }
        finally
        {
            Gate.Release();
        }

        var recommendations = new List<GoalRecommendation>();
        foreach (var (goalName, strategy) in Goals)
        {
            var rec = result.Recommendations.FirstOrDefault(r => r.Strategy.Value == strategy);
            if (rec is null)
            {
                warnings.Add(new RecommendationWarning { Code = "no_plan_for_goal", Subject = goalName });
                continue;
            }

            recommendations.Add(new GoalRecommendation
            {
                Goal = goalName,
                Best = ToDto(rec.Best),
                Alternatives = rec.Alternatives.Select(ToDto).ToList(),
            });
        }

        // A rotation needs at least MinCycleYears different crops that survive screening on this plot.
        var fitting = result.Screening.Count(s => s.IsCandidate && kb.GetCrop(s.Crop).IsMainCrop);
        if (fitting < kb.Strategies.Values.Min(s => s.MinCycleYears))
        {
            warnings.Add(new RecommendationWarning { Code = "few_crops_fit" });
        }

        // The asked-for goal may have no plan (nothing meets its survival floor). Show the next best goal
        // instead and say so, rather than an empty answer.
        var mainGoal = recommendations.Any(r => r.Goal == goal) ? goal
            : recommendations.Any(r => r.Goal == Balanced) ? Balanced
            : recommendations.FirstOrDefault()?.Goal ?? goal;
        if (mainGoal != goal)
        {
            warnings.Add(new RecommendationWarning { Code = "goal_unavailable", Subject = goal });
        }

        logger.LogInformation("Recommendations for {Lat},{Lon}: {Count} goals, asked {Goal}, main {Main}",
            roundedLat, roundedLon, recommendations.Count, goal, mainGoal);

        return new RecommendationResponse
        {
            ParcelId = request.ParcelId,
            Status = recommendations.Count > 0 ? "ok" : "no_plan",
            MainGoal = mainGoal,
            Recommendations = recommendations,
            Warnings = warnings,
            Inputs = inputs,
            GeneratedAtUtc = time.GetUtcNow(),
        };
    }


    /// <summary>What SoilGrids gave: a profile, nothing for this spot (Profile null), or a failed request (Failed).</summary>
    private sealed record SoilLookup(SoilProfile? Profile, bool Failed);

    /// <summary>Only the five properties the engine uses: a smaller SoilGrids query is much faster.</summary>
    private async Task<SoilLookup> GetSoilAsync(double lat, double lon, CancellationToken ct)
    {
        var key = string.Create(CultureInfo.InvariantCulture, $"engine-soil:{lat:F2}:{lon:F2}");
        if (cache.TryGetValue(key, out SoilLookup? cached) && cached is not null)
        {
            return cached;
        }

        SoilLookup lookup;
        try
        {
            var data = await SoilPipeline.ExecuteAsync(
                async token => await soilClient.GetTopsoilAsync(lat, lon, token, SoilGridsClient.EngineProperties), ct);
            lookup = new SoilLookup(FieldProfileService.BuildSoilProfile(data), Failed: false);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning(ex, "SoilGrids request failed for {Lat},{Lon}; using typical soil", lat, lon);
            lookup = new SoilLookup(null, Failed: true);
        }

        cache.Set(key, lookup, lookup.Profile is null ? TimeSpan.FromMinutes(5) : TimeSpan.FromHours(24));
        return lookup;
    }

    private async Task<ClimateData> GetClimateAsync(double lat, double lon, CancellationToken ct)
    {
        var key = string.Create(CultureInfo.InvariantCulture, $"engine-climate:{lat:F2}:{lon:F2}");
        if (cache.TryGetValue(key, out ClimateData? cached) && cached is not null)
        {
            return cached;
        }

        var last = time.GetUtcNow().Year - 1;
        NasaPowerDailyData daily;
        try
        {
            daily = await nasa.GetDailyAsync(lat, lon, new DateOnly(FirstClimateYear, 1, 1), new DateOnly(last, 12, 31),
                DailyParameters, ct);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogError(ex, "NASA POWER daily request failed for {Lat},{Lon}", lat, lon);
            throw new UpstreamServiceException("NASA POWER", ex);
        }

        var climate = BuildClimate(daily, FirstClimateYear, last);
        cache.Set(key, climate, TimeSpan.FromHours(24));
        return climate;
    }

    /// <summary>Days missing any of the three values are left out; the engine copes with gaps.</summary>
    internal static ClimateData BuildClimate(NasaPowerDailyData daily, int firstYear, int lastYear)
    {
        var tMin = daily.Parameters.GetValueOrDefault("T2M_MIN");
        var tMax = daily.Parameters.GetValueOrDefault("T2M_MAX");
        var rain = daily.Parameters.GetValueOrDefault("PRECTOTCORR");

        var years = new List<ClimateYear>();
        if (tMin is not null && tMax is not null && rain is not null)
        {
            for (var year = firstYear; year <= lastYear; year++)
            {
                var days = new List<DailyWeather>(366);
                for (var d = new DateOnly(year, 1, 1); d.Year == year; d = d.AddDays(1))
                {
                    if (tMin.TryGetValue(d, out var lo) && tMax.TryGetValue(d, out var hi) && rain.TryGetValue(d, out var mm))
                    {
                        days.Add(new DailyWeather(d, lo, Math.Max(hi, lo), Math.Max(mm, 0)));
                    }
                }

                if (days.Count > 300)
                {
                    years.Add(new ClimateYear(year, days));
                }
            }
        }

        return new ClimateData { Years = years, Source = "NASA POWER daily (MERRA-2 / IMERG, ~50 km grid)" };
    }

    private (SiteSoil Value, bool Estimated) BuildSoil(
        SoilLookup lookup, double lat, double lon, List<RecommendationWarning> warnings)
    {
        var soil = lookup.Profile;
        var missing = new List<string>();
        if (soil?.SandPct is null) missing.Add("sand");
        if (soil?.ClayPct is null) missing.Add("clay");
        if (soil?.SiltPct is null) missing.Add("silt");
        if (soil?.Ph is null) missing.Add("ph");
        if (soil?.OrganicCarbonGkg is null) missing.Add("soc");

        var estimated = missing.Count > 0;
        if (estimated)
        {
            var (code, reason) = lookup.Failed ? ("soil_unavailable", "the SoilGrids request failed")
                : soil is null ? ("soil_no_data", "SoilGrids has no data for this spot")
                : ("soil_partial", "SoilGrids returned only part of the values");
            warnings.Add(new RecommendationWarning
            {
                Code = code,
                Subject = code == "soil_partial" ? string.Join(',', missing) : null,
            });
            logger.LogWarning("Soil for {Lat},{Lon} uses typical values: {Reason}; missing: {Missing}",
                lat, lon, reason, string.Join(',', missing));
        }

        return (new SiteSoil
        {
            SandPct = soil?.SandPct ?? DefaultSand,
            ClayPct = soil?.ClayPct ?? DefaultClay,
            SiltPct = soil?.SiltPct ?? DefaultSilt,
            PhH2O = soil?.Ph ?? DefaultPh,
            OrganicCarbonGkg = soil?.OrganicCarbonGkg ?? DefaultSoc,
            BulkDensityGcm3 = soil?.BulkDensityGcm3 is { } bd ? bd : null,
            CecCmolKg = soil?.CecCmolKg is { } cec ? cec : null,
            Source = soil?.Source ?? "Typical Polish topsoil (estimate)",
        }, estimated);
    }

    /// <summary>Most recent crop first in the request; harvest years count back from the last finished season.</summary>
    private List<HistoricSeason> BuildHistory(IReadOnlyList<string> pastCrops, List<RecommendationWarning> warnings)
    {
        var now = time.GetUtcNow();
        var lastYear = now.Month >= 9 ? now.Year : now.Year - 1;

        var history = new List<HistoricSeason>();
        for (var i = 0; i < pastCrops.Count; i++)
        {
            var engineId = CropIdMap.ToEngine(pastCrops[i]);
            if (engineId is null || !engine.KnowledgeBase.Crops.ContainsKey(CropId.From(engineId)))
            {
                warnings.Add(new RecommendationWarning { Code = "crop_not_supported", Subject = pastCrops[i] });
                continue;
            }

            history.Add(new HistoricSeason
            {
                HarvestYear = lastYear - i,
                Crop = CropId.From(engineId),
                Source = HistorySource.Farmer,
            });
        }

        return history;
    }


    private RotationPlanDto ToDto(PlanEvaluation evaluation)
    {
        var plan = evaluation.Plan;
        var seasons = plan.Transition.Concat(plan.Cycle).ToList();

        PlanSeasonDto Season(int i)
        {
            var s = seasons[i];
            var e = evaluation.Seasons.FirstOrDefault(x => x.SeasonIndex == i);
            return new PlanSeasonDto
            {
                HarvestYear = plan.FirstHarvestYear + i,
                Crop = Crop(s.MainCrop),
                CatchCrop = s.CatchCrop is { } c ? Crop(c) : null,
                Harvest = Rate(e?.SurvivalMean ?? 0),
            };
        }

        var reasons = ReasonCollector.Aggregate(evaluation.Reasons)
            .Where(g => g.Code.StartsWith("effect.", StringComparison.Ordinal)
                        || g.Code.StartsWith("interaction.", StringComparison.Ordinal))
            .Where(g => Math.Abs(g.TotalDelta) > 1e-9)
            // The same effect repeats every cycle; show it once, with the average change per season.
            .GroupBy(g => (g.Code, Crop: g.Crop?.Value, Var: g.Var?.Value))
            .Select(g => new PlanReasonDto
            {
                Code = g.Key.Code,
                CropId = g.Key.Crop,
                Var = g.Key.Var,
                Delta = Math.Round(g.Sum(x => x.TotalDelta) / g.Sum(x => x.Count), 3),
            })
            .ToList();

        // Interactions are the plan-specific findings (this soil makes it better or worse), so they come first,
        // but at most a few: they must not push out the ordinary effects.
        var interactions = reasons.Where(r => r.Code.StartsWith("interaction.", StringComparison.Ordinal)).Take(3).ToList();
        reasons = interactions.Concat(reasons.Where(r => !r.Code.StartsWith("interaction.", StringComparison.Ordinal)))
            .Take(6)
            .ToList();

        return new RotationPlanDto
        {
            Transition = Enumerable.Range(0, plan.Transition.Count).Select(Season).ToList(),
            Cycle = Enumerable.Range(plan.Transition.Count, plan.Cycle.Count).Select(Season).ToList(),
            CycleYears = plan.CycleLength,
            Scores = ScoreKeys.Select(k => new PlanScoreDto { Key = k.Key, Rating = Rate(Normalised(k.Objective, evaluation.Scores[k.Objective])) }).ToList(),
            Reasons = reasons,
            IsFeasible = evaluation.IsFeasible,
            Problems = evaluation.Violations.Select(v => v.Code).Distinct().ToList(),
        };
    }

    // The survival objective is chance of harvest x yield factor minus penalties. The yield factor multiplies many
    // response curves that are below 1 even on good soil, so the best plans measured reach about 0.4-0.5, never 1.
    // Rating it on 0-1 would call every plan weak, so it is rated against this ceiling. A calibration of the
    // knowledge base (crops.json) would make this unnecessary.
    private const double HarvestCeiling = 0.5;

    private static double Normalised(Objective objective, double score) =>
        objective == Objective.Survival ? score / HarvestCeiling : score;

    private static readonly (string Key, Objective Objective)[] ScoreKeys =
    [
        ("harvest", Objective.Survival),
        ("humus", Objective.Humus),
        ("disease", Objective.Pathogen),
        ("water", Objective.Water),
        ("nitrogen", Objective.Nitrogen),
        ("cover", Objective.Cover),
        ("structure", Objective.Structure),
    ];

    private CropRef Crop(CropId id)
    {
        var crop = engine.KnowledgeBase.GetCrop(id);
        return new CropRef
        {
            Id = id.Value,
            Name = new Dictionary<string, string> { ["pl"] = crop.NamePl, ["en"] = crop.NameEn ?? crop.NamePl },
            CatalogId = CropIdMap.ToCatalog(id.Value),
            Sow = new DayRange(crop.SowWindow.Start, crop.SowWindow.End),
            Harvest = new DayRange(crop.HarvestWindow.Start, crop.HarvestWindow.End),
            SownPreviousYear = SeasonCalendar.SownPreviousYear(crop),
        };
    }

    internal static RatingDto Rate(double value)
    {
        var v = Math.Round(Math.Clamp(value, 0, 1), 2);
        return new RatingDto { Value = v, Level = v > 0.5 ? "good" : v >= 0.25 ? "ok" : "poor" };
    }
}
