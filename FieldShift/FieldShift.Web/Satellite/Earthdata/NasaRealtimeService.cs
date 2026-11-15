using System.Text.Json;
using FieldShift.Web.FieldData.Cache;
using Microsoft.Extensions.Caching.Memory;

namespace FieldShift.Web.Satellite.Earthdata;

/// <summary>
/// Near-real-time NASA data at a point, through Earthdata (token needed): rain from GPM IMERG (daily, ~10 km) and soil
/// moisture / temperature from SMAP L4 (9 km, every 3 hours, with a percentile against past years). Each value read is
/// kept in PostgreSQL (<c>provider_cache</c>); file lists from the catalogue stay in memory for an hour.
/// </summary>
public sealed class NasaRealtimeService(
    EarthdataClient earthdata,
    IProviderCache store,
    IMemoryCache memory,
    TimeProvider time,
    ILogger<NasaRealtimeService> logger)
{
    public const string Provider = "nasa-earthdata.v1";
    public const int RainDays = 30;
    public const int SoilDays = 14;
    public const int NormalYears = 3;
    public const double HeavyRainMm = 20;
    public const double WetDayMm = 1;
    public static readonly TimeSpan ValueTtl = TimeSpan.FromDays(30);
    public static readonly TimeSpan ListTtl = TimeSpan.FromHours(1);

    public const string RainSource = "NASA GPM IMERG Late Run v07 (opady dobowe, ok. 10 km) przez GES DISC";
    public const string SoilSource = "NASA SMAP L4 (wilgotność i temperatura gleby, 9 km, co 3 godziny) przez NSIDC";

    /// <summary>Requests to Earthdata at once, for all users together.</summary>
    private static readonly SemaphoreSlim Slots = new(6);

    public async Task<RainSection> RainAsync(double lat, double lon, CancellationToken ct)
    {
        if (!earthdata.IsConfigured)
        {
            return EmptyRain(SatelliteStatus.NotConfigured);
        }

        var now = time.GetUtcNow();
        var granules = await ListAsync("GPM_3IMERGDL", "07", now.AddDays(-(RainDays + 3)), now, 60, ct);
        var days = granules
            .GroupBy(g => DateOnly.FromDateTime(g.Start.UtcDateTime))
            .Select(g => g.First())
            .OrderByDescending(g => g.Start)
            .Take(RainDays)
            .ToList();
        if (days.Count == 0)
        {
            return EmptyRain(SatelliteStatus.NoData);
        }

        var (lonIndex, latIndex) = NasaGrids.Imerg(lat, lon);
        var values = await Task.WhenAll(days.Select(async g =>
        {
            var v = await ReadAsync(g, $"/precipitation[0][{lonIndex}][{latIndex}]", ct);
            var mm = v.TryGetValue("precipitation", out var p) && p >= 0 ? Math.Round(p, 1) : (double?)null;
            return new RainDay(DateOnly.FromDateTime(g.Start.UtcDateTime), mm);
        }));
        return SummarizeRain(values);
    }

    public async Task<SoilMoistureSection> SoilAsync(double lat, double lon, CancellationToken ct)
    {
        if (!earthdata.IsConfigured)
        {
            return EmptySoil(SatelliteStatus.NotConfigured);
        }

        var now = time.GetUtcNow();
        var granules = await ListAsync("SPL4SMGP", null, now.AddDays(-(SoilDays + 4)), now, 200, ct);
        if (granules.Count == 0)
        {
            return EmptySoil(SatelliteStatus.NoData);
        }

        // One file per day for the trend (the one nearest to midday UTC), plus the newest one.
        var latest = granules.OrderByDescending(g => g.Start).First();
        var daily = granules
            .GroupBy(g => DateOnly.FromDateTime(g.Start.UtcDateTime))
            .Select(g => g.OrderBy(x => Math.Abs(x.Start.UtcDateTime.Hour - 9)).First())
            .OrderByDescending(g => g.Start)
            .Take(SoilDays)
            .ToList();

        var (row, column) = NasaGrids.Smap9Km(lat, lon);
        string Cell(string name) => $"/Geophysical_Data/{name}[{row}][{column}]";
        var full = string.Join(';', new[]
        {
            "sm_rootzone_pctl", "sm_rootzone_wetness", "sm_surface_wetness", "sm_rootzone", "soil_temp_layer1",
            "snow_depth", "land_fraction_snow_covered",
        }.Select(Cell));
        var trend = string.Join(';', new[]
        {
            "sm_rootzone_wetness", "sm_rootzone_pctl", "sm_surface_wetness", "soil_temp_layer1",
        }.Select(Cell));

        var latestTask = ReadAsync(latest, full, ct);
        var normalTask = NormalWetnessAsync(latest.Start, trend, ct);
        var dayTasks = daily.Select(async g =>
        {
            var v = await ReadAsync(g, trend, ct);
            var k = Valid(v, "soil_temp_layer1", 2);
            return new SoilDay(DateOnly.FromDateTime(g.Start.UtcDateTime),
                Valid(v, "sm_rootzone_wetness", 3), Valid(v, "sm_rootzone_pctl", 0),
                Valid(v, "sm_surface_wetness", 3), k is { } kelvin ? Math.Round(kelvin - 273.15, 1) : null);
        }).ToList();
        var values = await latestTask;
        var days = (await Task.WhenAll(dayTasks)).OrderBy(d => d.Date).ToList();
        var (normal, normalYears) = await normalTask;

        var wetness = Valid(values, "sm_rootzone_wetness", 3);
        var pctl = Valid(values, "sm_rootzone_pctl", 0);
        var tempK = Valid(values, "soil_temp_layer1", 2);
        var tempC = tempK is { } k ? Math.Round(k - 273.15, 1) : (double?)null;
        if (pctl is null && wetness is null)
        {
            return EmptySoil(SatelliteStatus.NoData);
        }

        // Snow depth is given for the snow-covered part of the cell only: shown when snow covers most of it.
        var snowCover = Valid(values, "land_fraction_snow_covered", 2);
        var snowM = Valid(values, "snow_depth", 3);
        double? snowCm = snowCover is >= 0.5 && snowM is { } m ? Math.Round(m * 100, 0) : snowCover is null ? null : 0;

        return new SoilMoistureSection(
            SatelliteStatus.Ok, SoilSource, 9, latest.Start,
            pctl,
            wetness,
            Valid(values, "sm_surface_wetness", 3),
            Valid(values, "sm_rootzone", 3),
            tempC,
            snowCm,
            pctl is not null ? SoilLevel(pctl) : WetnessLevel(wetness, normal),
            tempC is < 0,
            days)
        {
            NormalRootzoneWetness = normal is { } n ? Math.Round(n, 3) : null,
            NormalYears = normalYears,
        };
    }

    /// <summary>
    /// Mean root zone wetness at the same time of year in the previous <see cref="NormalYears"/> years (SMAP L4
    /// starts in 2015); how many years had a value.
    /// </summary>
    private async Task<(double? Normal, int Years)> NormalWetnessAsync(DateTimeOffset at, string constraint, CancellationToken ct)
    {
        var values = new List<double>();
        for (var k = 1; k <= NormalYears; k++)
        {
            var day = at.AddYears(-k);
            try
            {
                var found = await ListAsync("SPL4SMGP", null, day.AddHours(-2), day.AddHours(2), 4, ct);
                if (found.OrderBy(g => Math.Abs((g.Start - day).TotalMinutes)).FirstOrDefault() is { } g
                    && Valid(await ReadAsync(g, constraint, ct), "sm_rootzone_wetness", 3) is { } w)
                {
                    values.Add(w);
                }
            }
            catch (Exception ex) when (ex is HttpRequestException or FormatException or TaskCanceledException)
            {
                logger.LogInformation(ex, "SMAP L4 for {Day:yyyy-MM-dd} unavailable; normal from fewer years", day);
            }
        }

        return values.Count == 0 ? (null, 0) : (values.Average(), values.Count);
    }

    /// <summary>Drier / wetter than usual from wetness against its normal (±15 %). Pure.</summary>
    public static string? WetnessLevel(double? wetness, double? normal) =>
        wetness is { } w && normal is { } n && n > 0.05
            ? w < 0.85 * n ? SatelliteLevel.Below : w > 1.15 * n ? SatelliteLevel.Above : SatelliteLevel.Normal
            : null;

    /// <summary>Sums and counts over the days, newest last in <see cref="RainSection.Days"/>. Pure.</summary>
    public static RainSection SummarizeRain(IEnumerable<RainDay> days)
    {
        var ordered = days.OrderBy(d => d.Date).ToList();
        var known = ordered.Where(d => d.Mm is not null).ToList();
        if (known.Count == 0)
        {
            return EmptyRain(SatelliteStatus.NoData) with { Days = ordered };
        }

        var latest = known[^1].Date;
        double? Sum(int n) => Math.Round(known.Where(d => d.Date > latest.AddDays(-n)).Sum(d => d.Mm!.Value), 1);
        var dryInRow = 0;
        foreach (var d in Enumerable.Reverse(known))
        {
            if (d.Mm >= WetDayMm)
            {
                break;
            }

            dryInRow++;
        }

        return new RainSection(SatelliteStatus.Ok, RainSource, 10, latest, Sum(1), Sum(7), Sum(30),
            known.Count(d => d.Mm >= HeavyRainMm), dryInRow, ordered);
    }

    /// <summary>Drier / wetter than usual from the root zone percentile. Pure.</summary>
    public static string? SoilLevel(double? percentile) => percentile switch
    {
        null => null,
        < 20 => SatelliteLevel.Below,
        > 80 => SatelliteLevel.Above,
        _ => SatelliteLevel.Normal,
    };

    public static RainSection EmptyRain(string status) =>
        new(status, RainSource, 10, null, null, null, null, null, null, []);

    public static SoilMoistureSection EmptySoil(string status) =>
        new(status, SoilSource, 9, null, null, null, null, null, null, null, null, false, []);

    /// <summary>A value that is not a fill value (SMAP and IMERG use large negative numbers), rounded.</summary>
    private static double? Valid(IReadOnlyDictionary<string, double> values, string name, int decimals) =>
        values.TryGetValue(name, out var v) && v > -9000 && double.IsFinite(v)
            ? Math.Round(v, decimals, MidpointRounding.AwayFromZero)
            : null;

    private async Task<IReadOnlyList<Granule>> ListAsync(
        string shortName, string? version, DateTimeOffset from, DateTimeOffset to, int max, CancellationToken ct)
    {
        var key = $"earthdata-list:{shortName}:{version}:{from.UtcDateTime:yyyyMMddHH}:{to.UtcDateTime:yyyyMMddHH}";
        if (memory.TryGetValue(key, out IReadOnlyList<Granule>? cached) && cached is not null)
        {
            return cached;
        }

        var list = await earthdata.FindGranulesAsync(shortName, version, from, to, max, ct);
        memory.Set(key, list, ListTtl);
        return list;
    }

    private async Task<IReadOnlyDictionary<string, double>> ReadAsync(Granule granule, string constraint, CancellationToken ct)
    {
        var key = $"{granule.CollectionId}:{granule.Title}:{constraint}";
        var now = time.GetUtcNow();
        if (await store.GetAsync(Provider, key, now, ct) is { Json: { } json }
            && JsonSerializer.Deserialize<Dictionary<string, double>>(json) is { } stored)
        {
            return stored;
        }

        IReadOnlyDictionary<string, double> values;
        await Slots.WaitAsync(ct);
        try
        {
            values = await earthdata.ReadAsync(granule, constraint, ct);
        }
        finally
        {
            Slots.Release();
        }

        await store.SetAsync(Provider, key, JsonSerializer.Serialize(values), now, now + ValueTtl, ct);
        return values;
    }

}
