using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;

namespace FieldShift.Prediction.Engine.Survival;

public sealed record CropScreeningResult
{
    public required CropId Crop { get; init; }
    public required bool IsCandidate { get; init; }
    public required bool ExcludedByFarmer { get; init; }
    public required double SurvivalMean { get; init; }
    public required double SurvivalCvar { get; init; }

    public required double Floor { get; init; }

    public required IReadOnlyList<YearSurvival> Years { get; init; }

    public required IReadOnlyList<int> WorstYears { get; init; }

    public string? LimitingFactor { get; init; }

    public required IReadOnlyList<Reason> Reasons { get; init; }
}

public sealed record ScreeningOutcome(
    StaticSurvivalTable Survival,
    IReadOnlyList<CropScreeningResult> Results,
    IReadOnlyList<Reason> Warnings)
{
    public IEnumerable<CropScreeningResult> Candidates => Results.Where(r => r.IsCandidate);

    public CropScreeningResult this[CropId crop] => Results.Single(r => r.Crop == crop);
}

public static class CropScreener
{
    private const double NotLimiting = 0.999;

    public static ScreeningOutcome Screen(
        CropKnowledgeBase kb, PlotFeatures features, ClimateIndex climate, FarmerInputs farmer,
        EngineSettings settings, IReadOnlyCollection<Strategy> strategies)
    {
        if (strategies.Count == 0)
            throw new ArgumentException("At least one strategy is needed to know the survival floor.", nameof(strategies));

        var floor = strategies.Min(s => s.SurvivalFloor);
        var excluded = farmer.ExcludedCrops.ToHashSet();

        var survival = kb.Crops.Values
            .OrderBy(c => c.Id.Value, StringComparer.Ordinal)
            .Select(c => StaticSuitabilityScorer.Score(c, features, climate, farmer, settings))
            .ToList();

        var results = survival.Select(s => Describe(s, floor, excluded.Contains(s.Crop), settings)).ToList();
        var warnings = survival.SelectMany(s => s.Reasons).ToList();
        if (climate.Et0EstimatedDays > 0)
            warnings.Add(new Reason
            {
                SeasonIndex = FeatureBuilder.PlotLevel,
                Kind = ReasonKind.Suitability,
                Code = "climate.et0Estimated",
                Value = climate.Et0EstimatedDays,
                Message = Fmt.Inv($"ET0 was estimated with Hargreaves–Samani on {climate.Et0EstimatedDays} of {climate.DayCount} days.")
            });

        return new ScreeningOutcome(new StaticSurvivalTable(survival), results, warnings);
    }

    private static CropScreeningResult Describe(CropStaticSurvival s, double floor, bool farmerExcluded, EngineSettings settings)
    {
        var reasons = new List<Reason>(s.Reasons);

        var worst = s.Years.OrderBy(y => y.Score).ThenBy(y => y.HarvestYear).ToList();
        var k = s.Years.Count == 0 ? 0 : SurvivalAggregator.WorstCount(s.Years.Count, settings.Survival.CvarFraction);
        var worstYears = worst.Take(k).Select(y => y.HarvestYear).ToList();

        var (limiting, limitingMean) = LimitingFactor(s);
        if (limiting is not null)
            reasons.Add(new Reason
            {
                SeasonIndex = FeatureBuilder.PlotLevel,
                Kind = ReasonKind.Suitability,
                Code = Fmt.Inv($"screening.limitingFactor.{limiting}"),
                Crop = s.Crop,
                Value = limitingMean,
                Delta = limitingMean - 1.0,
                Message = Fmt.Inv($"{limiting} limits survival (mean score {limitingMean:F2}); worst years: {string.Join(", ", worstYears)}.")
            });

        var belowFloor = s.Cvar < floor;
        if (farmerExcluded)
            reasons.Add(new Reason
            {
                SeasonIndex = FeatureBuilder.PlotLevel, Kind = ReasonKind.Suitability,
                Code = "screening.excluded.farmer", Crop = s.Crop, Message = "The farmer excluded this crop."
            });
        if (belowFloor)
            reasons.Add(new Reason
            {
                SeasonIndex = FeatureBuilder.PlotLevel, Kind = ReasonKind.Suitability,
                Code = "screening.excluded.survivalFloor", Crop = s.Crop, Value = s.Cvar, Delta = s.Cvar - floor,
                Message = Fmt.Inv($"Survival in the worst years is {s.Cvar:F2}, below the minimum {floor:F2}") +
                          (limiting is null ? "." : Fmt.Inv($"; limiting factor: {limiting}."))
            });

        return new CropScreeningResult
        {
            Crop = s.Crop,
            IsCandidate = !belowFloor && !farmerExcluded,
            ExcludedByFarmer = farmerExcluded,
            SurvivalMean = s.Mean,
            SurvivalCvar = s.Cvar,
            Floor = floor,
            Years = s.Years,
            WorstYears = worstYears,
            LimitingFactor = limiting,
            Reasons = reasons
        };
    }

    private static (string? Name, double Mean) LimitingFactor(CropStaticSurvival s)
    {
        string? best = null;
        var bestMean = 1.0;
        foreach (var name in SurvivalFactors.Names)
        {
            var values = s.Years.Select(y => y.Factors.Get(name)).OfType<double>().ToList();
            if (values.Count == 0) continue;

            var mean = values.Average();
            if (mean < bestMean - 1e-12)
                (best, bestMean) = (name, mean);
        }
        return bestMean >= NotLimiting ? (null, 1.0) : (best, bestMean);
    }
}
