using FieldShift.Web.Countries;
using System.Globalization;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldData;
using FieldShift.Web.FieldData.Cache;
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
    NasaDailyCache nasaClient,
    ISoilPropertiesProvider soilProvider,
    FieldDataCache fieldData,
    ParcelLookupCache parcels,
    IEnumerable<ITerrainProvider> terrains,
    IMemoryCache cache,
    IOptions<DemoLocationsOptions> demoLocations,
    TimeProvider time,
    ILogger<MapLayersService> logger)
{
    internal static readonly string[] BaseParameters = ["T2M", "T2M_MAX", "T2M_MIN", "PRECTOTCORR", "GWETROOT", "RH2M"];
    private const string EvaporationParameter = "EVPTRNS";
    private static readonly TimeSpan CacheTtl = TimeSpan.FromHours(24);

    /// <summary>A response without soil or parcel slope (slow sources not back yet) is kept only briefly.</summary>
    private static readonly TimeSpan PartialCacheTtl = TimeSpan.FromMinutes(2);

    /// <summary>
    /// How long the map waits for the optional sources (SoilGrids, the parcel's slope) after NASA has answered.
    /// They keep loading in the background and are stored, so the next request has them.
    /// </summary>
    public static readonly TimeSpan OptionalSourcesWait = TimeSpan.FromSeconds(2);

    /// <summary>Longest an optional source may load in the background.</summary>
    private static readonly TimeSpan OptionalSourcesTimeout = TimeSpan.FromSeconds(60);

    public const string ResolutionWarning =
        "Dane NASA POWER mają rozdzielczość ok. 50 km – jedna wartość dla całej okolicy pola.";

    public const string EstimatesWarning =
        "Stres roślinny, ryzyko erozji, pogoda sprzyjająca chorobom grzybowym i ciepło sprzyjające szkodnikom to wskaźniki "
        + "szacunkowe, liczone z danych klimatycznych i glebowych. Nie wykrywają chorób ani szkodników na polu.";

    public const string NoSlopeWarning =
        "Brak danych o nachyleniu terenu – erozja liczona bez ukształtowania terenu.";

    public const string NoSoilForErosionWarning =
        "Brak danych glebowych (ISRIC SoilGrids) – ryzyko erozji liczone dla przeciętnej podatności gleby (0,6).";

    public const string ErosionSourceWithoutTerrain = "Szacunek z NASA POWER (PRECTOTCORR) i ISRIC SoilGrids";

    public const string NoSoilWarning = "Brak danych glebowych (ISRIC SoilGrids) dla tego punktu.";

    public const string NoEvaporationWarning =
        "Dane o parowaniu (EVPTRNS) są niedostępne w NASA POWER – pominięto warstwę „Parowanie”.";

    /// <summary>Slope of the registered parcel at the point, for the erosion estimate.</summary>
    private sealed record ParcelSlope(string ParcelId, double SlopePct, string Source);

    public async Task<MapLayersResponse> GetAsync(MapLayersRequest request, CancellationToken ct)
    {
        // The parcel is looked up at the exact point (the NASA data below uses a rounded one).
        var (exactLat, exactLon) = (request.Lat, request.Lon);
        var wantsErosion = request.LayerIds.Contains(LayerDefinitions.ErosionRisk);
        request = request with
        {
            Lat = Math.Round(request.Lat, 2, MidpointRounding.AwayFromZero),
            Lon = Math.Round(request.Lon, 2, MidpointRounding.AwayFromZero),
        };
        var cacheKey = string.Create(CultureInfo.InvariantCulture,
            $"map-layers:{exactLat:F5}:{exactLon:F5}:{request.From}:{request.To}:{string.Join(',', request.LayerIds)}");

        if (cache.TryGetValue(cacheKey, out MapLayersResponse? cached) && cached is not null)
        {
            return cached;
        }

        var wantsEvaporation = request.LayerIds.Contains(LayerDefinitions.Evaporation);

        // All sources at once. Only NASA is needed for the map; soil and the parcel's slope (both slow the first
        // time) are not tied to this request, so they finish and get stored even when the map does not wait.
        var slopeTask = wantsErosion
            ? FindParcelSlopeAsync(exactLat, exactLon)
            : Task.FromResult<ParcelSlope?>(null);
        var soilTask = FetchSoilAsync(request);
        var (nasa, evaporationAvailable) = await FetchNasaAsync(request, wantsEvaporation, ct);

        var deadline = Task.Delay(OptionalSourcesWait, ct);
        var (soilData, soilDone) = await Within(soilTask, deadline);
        var (parcelSlope, slopeDone) = await Within(slopeTask, deadline);
        var soil = FieldProfileService.BuildSoilProfile(soilData);
        var demoLocation = parcelSlope is null
            ? DerivedIndices.FindDemoLocation(request.Lat, request.Lon, demoLocations.Value.Locations)
            : new DemoLocation { Name = parcelSlope.ParcelId, Lat = request.Lat, Lon = request.Lon, SlopePct = parcelSlope.SlopePct };

        var response = Compose(request, nasa, evaporationAvailable, soil, demoLocation, time.GetUtcNow(),
            parcelSlope?.Source);
        cache.Set(cacheKey, response, soilDone && slopeDone ? CacheTtl : PartialCacheTtl);
        return response;
    }

    /// <summary>The task's result if it finishes before <paramref name="deadline"/>; (default, false) otherwise.</summary>
    private static async Task<(T? Value, bool Done)> Within<T>(Task<T?> task, Task deadline)
    {
        if (!task.IsCompleted)
        {
            try
            {
                await Task.WhenAny(task, deadline);
            }
            catch (OperationCanceledException)
            {
                // The request was cancelled: the caller stops anyway.
            }
        }

        return task.IsCompletedSuccessfully ? (task.Result, true) : (default, false);
    }

    /// <summary>
    /// The registered parcel at the point and its slope from the country's terrain model (Poland: GUGiK, 1 m),
    /// through the field data cache; null where there is no parcel, no terrain source or a source fails (erosion
    /// is then estimated without terrain, as before). The parcel lookup is kept in memory for a day.
    /// </summary>
    private async Task<ParcelSlope?> FindParcelSlopeAsync(double lat, double lon)
    {
        using var timeout = new CancellationTokenSource(OptionalSourcesTimeout);
        var ct = timeout.Token;
        var key = string.Create(CultureInfo.InvariantCulture, $"parcel-slope:{lat:F5}:{lon:F5}");
        if (cache.TryGetValue(key, out ParcelSlope? known))
        {
            return known;
        }

        ParcelSlope? result = null;
        try
        {
            if (await parcels.AtAsync(lat, lon, ct) is { } field
                && FieldDataCache.Pick(terrains, field) is { } terrain
                && (await fieldData.GetAsync(terrain, field, ct)).Value is { } info)
            {
                result = new ParcelSlope(field.ParcelId!, info.SlopePct, info.Source);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Parcel slope for {Lat},{Lon} unavailable; erosion without terrain", lat, lon);
            return null;
        }

        cache.Set(key, result, CacheTtl);
        return result;
    }

    private async Task<(NasaPowerDailyData Data, bool EvaporationAvailable)> FetchNasaAsync(
        MapLayersRequest request, bool wantsEvaporation, CancellationToken ct)
    {
        try
        {
            if (wantsEvaporation)
            {
                try
                {
                    var withEvaporation = await GetDailyAsync(request, [.. BaseParameters, EvaporationParameter], ct);
                    var available = withEvaporation.Parameters.TryGetValue(EvaporationParameter, out var series) && series.Count > 0;
                    return (withEvaporation, available);
                }
                catch (HttpRequestException ex) when ((int?)ex.StatusCode is >= 400 and < 500)
                {
                    // NASA POWER rejects unknown parameters with 4xx: retry without EVPTRNS.
                    logger.LogWarning(ex, "NASA POWER daily rejected {Parameter}; retrying without it", EvaporationParameter);
                }
            }

            return (await GetDailyAsync(request, BaseParameters, ct), false);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogError(ex, "NASA POWER daily request failed for {Lat},{Lon} {From}..{To}",
                request.Lat, request.Lon, request.From, request.To);
            throw new UpstreamServiceException("NASA POWER", ex);
        }
    }

    private Task<NasaPowerDailyData> GetDailyAsync(MapLayersRequest request, string[] parameters, CancellationToken ct) =>
        nasaClient.GetAsync(request.Lat, request.Lon, request.From.FirstDay, request.To.LastDay, parameters, ct);

    private async Task<SoilGridsData?> FetchSoilAsync(MapLayersRequest request)
    {
        using var timeout = new CancellationTokenSource(OptionalSourcesTimeout);
        try
        {
            // Cached in PostgreSQL for months: SoilGrids is slow and its model rarely changes.
            return (await fieldData.GetAsync(soilProvider, new FieldLocation(request.Lat, request.Lon), timeout.Token)).Value;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "SoilGrids request failed for {Lat},{Lon}; map layers without soil", request.Lat, request.Lon);
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
        DateTimeOffset generatedAtUtc,
        string? terrainSource = null)
    {
        var climate = MonthlyAggregator.Aggregate(nasa, request.From, request.To);
        var months = climate.Months;
        var n = months.Count;

        var susceptibility = DerivedIndices.SoilSusceptibility(soil?.SoilClass);
        var slopeFactor = DerivedIndices.SlopeFactor(demoLocation?.SlopePct);
        var plantStress = Enumerable.Range(0, n)
            .Select(i => DerivedIndices.PlantStress(climate.SoilMoistureMean[i], climate.HeatDays[i]))
            .ToArray();
        var stressParts = Enumerable.Range(0, n)
            .Select(i => climate.SoilMoistureMean[i] is { } m && climate.HeatDays[i] is { } h
                ? DerivedIndices.PlantStressParts(m, h)
                : ((double, double)?)null)
            .ToArray();
        var degreeDays = DerivedIndices.CumulativeDegreeDays(months, climate.DegreeDays);
        var erosionRisk = Enumerable.Range(0, n)
            .Select(i => DerivedIndices.ErosionRisk(climate.ExtremeRainDays[i], susceptibility, slopeFactor))
            .ToArray();

        var warnings = new List<string> { ResolutionWarning };
        var ids = request.LayerIds;
        if (ids.Any(id => LayerDefinitions.Find(id)?.IsEstimate == true))
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
                LayerDefinitions.PlantStress => (plantStress, new Dictionary<string, double?[]>
                {
                    // Points of the 0–100 score: drought in the root zone (0–60) and hot days (0–40).
                    ["drought"] = stressParts.Select(p => p?.Item1).ToArray(),
                    ["heat"] = stressParts.Select(p => p?.Item2).ToArray(),
                    ["soilMoisture"] = climate.SoilMoistureMean,
                    ["heatDays"] = climate.HeatDays,
                }),
                LayerDefinitions.FungalRisk => (climate.FungalDays, null),
                LayerDefinitions.PestHeat => (degreeDays, null),
                LayerDefinitions.ErosionRisk => (erosionRisk, null),
                _ => throw new InvalidOperationException($"No data mapping for layer '{definition.Id}'."),
            };

            var series = BuildSeries(definition, values, extra, months);
            if (definition.Id == LayerDefinitions.ErosionRisk && terrainSource is not null)
            {
                // The slope is the parcel's own, not SRTM's.
                series = series with { Source = $"{ErosionSourceWithoutTerrain}, spadek działki: {terrainSource}" };
            }

            layers.Add(series);
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
                        Source = terrainSource ?? "NASA SRTM (przez AppEEARS)",
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
            Extra = extra?.ToDictionary(kv => kv.Key, kv => (IReadOnlyList<double?>)RoundAll(kv.Value, 2)),
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
