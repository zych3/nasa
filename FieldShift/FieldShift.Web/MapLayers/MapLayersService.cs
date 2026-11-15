using System.Globalization;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace FieldShift.Web.MapLayers;

public sealed class DemoLocationsOptions
{
    public List<DemoLocation> Locations { get; set; } = [];
}

/// <summary>
/// Orchestration for <c>GET /api/map-layers</c>: fetches NASA POWER daily data and SoilGrids in parallel, aggregates
/// to months and caches the response. <see cref="Compose"/> is the pure part (no HTTP) used by tests.
/// </summary>
public sealed class MapLayersService(
    NasaPowerClient nasaClient,
    SoilGridsClient soilClient,
    IMemoryCache cache,
    IOptions<DemoLocationsOptions> demoLocations,
    TimeProvider time,
    ILogger<MapLayersService> logger)
{
    internal static readonly string[] BaseParameters = ["T2M", "T2M_MAX", "T2M_MIN", "PRECTOTCORR", "GWETROOT"];
    private const string EvaporationParameter = "EVPTRNS";
    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(24);

    public const string ResolutionWarning =
        "Dane NASA POWER mają rozdzielczość ok. 50 km – jedna wartość dla całej okolicy pola.";

    public const string EstimatesWarning =
        "Stres roślinny i ryzyko erozji to wskaźniki szacunkowe, liczone z danych klimatycznych i glebowych.";

    public const string NoSlopeWarning =
        "Brak danych o nachyleniu terenu – erozja liczona bez ukształtowania terenu.";

    public const string NoSoilForErosionWarning =
        "Brak danych glebowych (ISRIC SoilGrids) – ryzyko erozji liczone dla przeciętnej podatności gleby (0,6).";

    public const string NoSoilWarning = "Brak danych glebowych (ISRIC SoilGrids) dla tego punktu.";

    public const string NoEvaporationWarning =
        "Dane o parowaniu (EVPTRNS) są niedostępne w NASA POWER – pominięto warstwę „Parowanie”.";

    public async Task<MapLayersResponse> GetAsync(MapLayersRequest request, CancellationToken ct)
    {
        request = request with
        {
            Lat = Math.Round(request.Lat, 2, MidpointRounding.AwayFromZero),
            Lon = Math.Round(request.Lon, 2, MidpointRounding.AwayFromZero),
        };
        var cacheKey = string.Create(CultureInfo.InvariantCulture,
            $"map-layers:{request.Lat:F2}:{request.Lon:F2}:{request.From}:{request.To}:{string.Join(',', request.LayerIds)}");

        if (cache.TryGetValue(cacheKey, out MapLayersResponse? cached) && cached is not null)
        {
            return cached;
        }

        var wantsEvaporation = request.LayerIds.Contains(LayerDefinitions.Evaporation);

        // If NASA fails there is nothing to show, so cancel the (slow) SoilGrids call right away.
        using var upstreamCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var nasaTask = FetchNasaAsync(request, wantsEvaporation, upstreamCts, ct);
        var soilTask = FetchSoilAsync(request, upstreamCts.Token, ct);
        await Task.WhenAll(nasaTask, soilTask);

        var (nasa, evaporationAvailable) = nasaTask.Result;
        var soil = FieldProfileService.BuildSoilProfile(soilTask.Result);
        var demoLocation = DerivedIndices.FindDemoLocation(request.Lat, request.Lon, demoLocations.Value.Locations);

        var response = Compose(request, nasa, evaporationAvailable, soil, demoLocation, time.GetUtcNow());
        cache.Set(cacheKey, response, CacheTtl);
        return response;
    }

    private async Task<(NasaPowerDailyData Data, bool EvaporationAvailable)> FetchNasaAsync(
        MapLayersRequest request, bool wantsEvaporation, CancellationTokenSource upstreamCts, CancellationToken requestCt)
    {
        try
        {
            if (wantsEvaporation)
            {
                try
                {
                    var withEvaporation = await GetDailyAsync(request, [.. BaseParameters, EvaporationParameter], upstreamCts.Token);
                    var available = withEvaporation.Parameters.TryGetValue(EvaporationParameter, out var series) && series.Count > 0;
                    return (withEvaporation, available);
                }
                catch (HttpRequestException ex) when ((int?)ex.StatusCode is >= 400 and < 500)
                {
                    // NASA POWER rejects unknown parameters with 4xx: retry without EVPTRNS.
                    logger.LogWarning(ex, "NASA POWER daily rejected {Parameter}; retrying without it", EvaporationParameter);
                }
            }

            return (await GetDailyAsync(request, BaseParameters, upstreamCts.Token), false);
        }
        catch (Exception ex) when (!requestCt.IsCancellationRequested)
        {
            logger.LogError(ex, "NASA POWER daily request failed for {Lat},{Lon} {From}..{To}",
                request.Lat, request.Lon, request.From, request.To);
            await upstreamCts.CancelAsync();
            throw new UpstreamServiceException("NASA POWER", ex);
        }
    }

    private Task<NasaPowerDailyData> GetDailyAsync(MapLayersRequest request, string[] parameters, CancellationToken ct) =>
        nasaClient.GetDailyAsync(request.Lat, request.Lon, request.From.FirstDay, request.To.LastDay, parameters, ct);

    private async Task<SoilGridsData?> FetchSoilAsync(
        MapLayersRequest request, CancellationToken upstreamCt, CancellationToken requestCt)
    {
        try
        {
            return await soilClient.GetTopsoilAsync(request.Lat, request.Lon, upstreamCt);
        }
        catch (Exception ex) when (!requestCt.IsCancellationRequested)
        {
            if (!upstreamCt.IsCancellationRequested)
            {
                logger.LogWarning(ex, "SoilGrids request failed for {Lat},{Lon}; map layers without soil", request.Lat, request.Lon);
            }

            return null;
        }
    }

    /// <summary>Builds the response from already-fetched data. Pure: no HTTP, cache or clock.</summary>
    public static MapLayersResponse Compose(
        MapLayersRequest request,
        NasaPowerDailyData nasa,
        bool evaporationAvailable,
        SoilProfile? soil,
        DemoLocation? demoLocation,
        DateTimeOffset generatedAtUtc)
    {
        var climate = MonthlyAggregator.Aggregate(nasa, request.From, request.To);
        var months = climate.Months;
        var n = months.Count;

        var susceptibility = DerivedIndices.SoilSusceptibility(soil?.SoilClass);
        var slopeFactor = DerivedIndices.SlopeFactor(demoLocation?.SlopePct);
        var plantStress = Enumerable.Range(0, n)
            .Select(i => DerivedIndices.PlantStress(climate.SoilMoistureMean[i], climate.HeatDays[i]))
            .ToArray();
        var erosionRisk = Enumerable.Range(0, n)
            .Select(i => DerivedIndices.ErosionRisk(climate.ExtremeRainDays[i], susceptibility, slopeFactor))
            .ToArray();

        var warnings = new List<string> { ResolutionWarning };
        var ids = request.LayerIds;
        if (ids.Contains(LayerDefinitions.PlantStress) || ids.Contains(LayerDefinitions.ErosionRisk))
        {
            warnings.Add(EstimatesWarning);
        }

        var layers = new List<LayerSeries>();
        foreach (var definition in ids.Select(id => LayerDefinitions.Find(id)!))
        {
            if (definition.Id == LayerDefinitions.Evaporation && !evaporationAvailable)
            {
                warnings.Add(NoEvaporationWarning);
                continue;
            }

            var (values, extra) = definition.Id switch
            {
                LayerDefinitions.Temperature => (climate.TempMean, new Dictionary<string, double?[]>
                {
                    ["max"] = climate.TempMax,
                    ["min"] = climate.TempMin,
                }),
                LayerDefinitions.HeatStress => (climate.HeatDays, null),
                LayerDefinitions.FrostRisk => (climate.FrostDays, null),
                LayerDefinitions.Precipitation => (climate.PrecipitationSum, null),
                LayerDefinitions.ExtremeRain => (climate.ExtremeRainDays, new Dictionary<string, double?[]>
                {
                    ["maxDailyMm"] = climate.MaxDailyPrecipitation,
                }),
                LayerDefinitions.SoilMoisture => (climate.SoilMoistureMean, null),
                LayerDefinitions.Evaporation => (climate.EvaporationSum, null),
                LayerDefinitions.PlantStress => (plantStress, null),
                LayerDefinitions.ErosionRisk => (erosionRisk, null),
                _ => throw new InvalidOperationException($"No data mapping for layer '{definition.Id}'."),
            };

            layers.Add(BuildSeries(definition, values, extra, months));
        }

        var withGaps = layers.Where(l => l.Values.Any(v => v is null)).Select(l => l.Name).ToList();
        if (withGaps.Count > 0)
        {
            warnings.Add($"Brak danych NASA POWER dla części miesięcy w warstwach: {string.Join(", ", withGaps)} – na mapie te miesiące będą puste.");
        }

        if (soil is null)
        {
            warnings.Add(ids.Contains(LayerDefinitions.ErosionRisk) ? NoSoilForErosionWarning : NoSoilWarning);
        }

        if (demoLocation is null && ids.Contains(LayerDefinitions.ErosionRisk))
        {
            warnings.Add(NoSlopeWarning);
        }

        return new MapLayersResponse
        {
            Location = new MapLocation { Lat = request.Lat, Lon = request.Lon },
            Period = new MapPeriod { From = request.From.ToString(), To = request.To.ToString() },
            Granularity = "month",
            Dates = months.Select(m => m.ToString()).ToList(),
            DefaultLayerId = layers.Any(l => l.Id == LayerDefinitions.SoilMoisture)
                ? LayerDefinitions.SoilMoisture
                : layers.FirstOrDefault()?.Id ?? LayerDefinitions.SoilMoisture,
            DefaultIndex = Math.Max(0, n - 1),
            Layers = layers,
            Static = new StaticLayers
            {
                Soil = soil is null
                    ? null
                    : new MapSoil
                    {
                        Source = "ISRIC SoilGrids v2.0 (0–30 cm)",
                        SoilClass = soil.SoilClass,
                        SandPct = soil.SandPct,
                        ClayPct = soil.ClayPct,
                        Ph = soil.Ph,
                    },
                Terrain = demoLocation is null
                    ? null
                    : new MapTerrain
                    {
                        Source = "NASA SRTM (przez AppEEARS)",
                        SlopePct = demoLocation.SlopePct,
                        SlopeClass = DerivedIndices.SlopeClass(demoLocation.SlopePct),
                    },
            },
            Warnings = warnings,
            GeneratedAtUtc = generatedAtUtc,
        };
    }

    private static LayerSeries BuildSeries(
        LayerDefinition definition,
        double?[] values,
        Dictionary<string, double?[]>? extra,
        IReadOnlyList<YearMonth> months)
    {
        var decimals = definition.Decimals;
        var (min, max, mean) = TrendCalculator.Stats(values);

        return new LayerSeries
        {
            Id = definition.Id,
            Name = definition.Name,
            Unit = definition.Unit,
            Group = definition.Group,
            Order = definition.Order,
            Decimals = decimals,
            IsEstimate = definition.IsEstimate,
            Source = definition.Source,
            Description = definition.Description,
            Values = RoundAll(values, decimals),
            Anomalies = definition.HasAnomalies ? RoundAll(TrendCalculator.Anomalies(values, months), decimals) : null,
            Extra = extra?.ToDictionary(kv => kv.Key, kv => (IReadOnlyList<double?>)RoundAll(kv.Value, 1)),
            Legend = definition.Legend,
            AnomalyLegend = definition.AnomalyLegend,
            Stats = new LayerStats
            {
                Min = Round(min, decimals),
                Max = Round(max, decimals),
                Mean = Round(mean, decimals),
                TrendPerDecade = Round(TrendCalculator.TrendPerDecade(values, months, definition.YearlyAggregation), decimals + 1),
            },
        };
    }

    private static double?[] RoundAll(IEnumerable<double?> values, int decimals) =>
        values.Select(v => Round(v, decimals)).ToArray();

    private static double? Round(double? value, int decimals) =>
        value is { } v ? Math.Round(v, decimals, MidpointRounding.AwayFromZero) : null;
}
