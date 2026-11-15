using System.Globalization;
using System.Text.Json;
using FieldShift.Web.FieldData.Cache;
using Microsoft.Extensions.Caching.Memory;

namespace FieldShift.Web.Satellite;

/// <summary>
/// <c>GET /api/satellite</c>: NASA MODIS at a field (ORNL DAAC subsets, no login): plant greenness (MOD13Q1 NDVI),
/// land surface temperature (MOD11A2) and evapotranspiration (MOD16A2GF), each compared with the same time of year
/// in the previous <see cref="NormalYears"/> years. Sections load in parallel and fail on their own.
/// <para>
/// Every downloaded piece is kept in PostgreSQL (<c>provider_cache</c>): past years for a year (they do not change),
/// the current year for <see cref="CurrentYearTtl"/>; the whole answer stays in memory for <see cref="ResponseTtl"/>.
/// </para>
/// </summary>
public sealed class SatelliteService(
    OrnlModisClient ornl,
    Earthdata.NasaRealtimeService realtime,
    IProviderCache store,
    IMemoryCache memory,
    TimeProvider time,
    ILogger<SatelliteService> logger)
{
    public const int NormalYears = 2;

    /// <summary>Latest composites of temperature and evapotranspiration that are read (8-day: about 7 weeks).</summary>
    public const int RecentComposites = 6;

    public const string Provider = "nasa-modis-ornl.v1";

    public static readonly TimeSpan CurrentYearTtl = TimeSpan.FromDays(2);
    public static readonly TimeSpan PastYearTtl = TimeSpan.FromDays(365);
    public static readonly TimeSpan DatesTtl = TimeSpan.FromDays(1);
    public static readonly TimeSpan ResponseTtl = TimeSpan.FromHours(6);

    public const string NdviSource = "NASA MODIS Terra MOD13Q1 v061 (NDVI, 250 m, co 16 dni) przez ORNL DAAC";
    public const string LstSource = "NASA MODIS Terra MOD11A2 v061 (temperatura powierzchni, 1 km, co 8 dni) przez ORNL DAAC";
    public const string EtSource = "NASA MODIS Terra MOD16A2 v061 (ewapotranspiracja, 500 m, co 8 dni) przez ORNL DAAC";

    /// <summary>Requests to ORNL at once, for all users together (a free service).</summary>
    private static readonly SemaphoreSlim Slots = new(6);

    /// <summary>Parts of the answer that can be asked for one by one (<c>GET /api/satellite/{part}</c>).</summary>
    public static readonly IReadOnlyList<string> Parts =
        ["rain", "soil", "vegetation", "surface-temperature", "evapotranspiration"];

    /// <summary>Longest a part may keep loading after the browser stopped waiting.</summary>
    public static readonly TimeSpan BackgroundTimeout = TimeSpan.FromMinutes(3);

    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, Lazy<Task<object>>> InFlight = new();

    public async Task<SatelliteResponse> GetAsync(double lat, double lon, CancellationToken ct)
    {
        var parts = await Task.WhenAll(Parts.Select(p => GetPartAsync(p, lat, lon, ct)));
        (lat, lon) = Round(lat, lon);
        return new SatelliteResponse(
            new SatelliteLocation(lat, lon),
            (RainSection)parts[0], (SoilMoistureSection)parts[1], (VegetationSection)parts[2],
            (SurfaceTemperatureSection)parts[3], (EvapotranspirationSection)parts[4], time.GetUtcNow());
    }

    /// <summary>
    /// One part (see <see cref="Parts"/>). Loading is not tied to <paramref name="ct"/>: it finishes and is kept even
    /// when the browser gives up, and requests for the same part at the same time share it.
    /// </summary>
    public async Task<object> GetPartAsync(string part, double lat, double lon, CancellationToken ct)
    {
        (lat, lon) = Round(lat, lon);
        var key = string.Create(CultureInfo.InvariantCulture, $"satellite:{part}:{lat:F3}:{lon:F3}");
        if (memory.TryGetValue(key, out object? cached) && cached is not null)
        {
            return cached;
        }

        var lazy = InFlight.GetOrAdd(key, _ => new Lazy<Task<object>>(() => LoadPartAsync(key, part, lat, lon)));
        try
        {
            return await lazy.Value.WaitAsync(ct);
        }
        finally
        {
            if (lazy.Value.IsCompleted)
            {
                InFlight.TryRemove(new KeyValuePair<string, Lazy<Task<object>>>(key, lazy));
            }
        }
    }

    private async Task<object> LoadPartAsync(string key, string part, double lat, double lon)
    {
        using var timeout = new CancellationTokenSource(BackgroundTimeout);
        var ct = timeout.Token;
        object result = part switch
        {
            "rain" => await Safe(() => realtime.RainAsync(lat, lon, ct), Earthdata.NasaRealtimeService.EmptyRain),
            "soil" => await Safe(() => realtime.SoilAsync(lat, lon, ct), Earthdata.NasaRealtimeService.EmptySoil),
            "vegetation" => await Safe(() => VegetationAsync(lat, lon, ct),
                s => new VegetationSection(s, NdviSource, 250, 0, null, null, null, [])),
            "surface-temperature" => await Safe(() => TemperatureAsync(lat, lon, ct),
                s => new SurfaceTemperatureSection(s, LstSource, 1000, 0, null, null, null, null, null, false)),
            "evapotranspiration" => await Safe(() => EvapotranspirationAsync(lat, lon, ct),
                s => new EvapotranspirationSection(s, EtSource, 500, 0, null, null)),
            _ => throw new ArgumentOutOfRangeException(nameof(part), part, "Unknown satellite part."),
        };
        var failed = result switch
        {
            RainSection r => r.Status == SatelliteStatus.Unavailable,
            SoilMoistureSection r => r.Status == SatelliteStatus.Unavailable,
            VegetationSection r => r.Status == SatelliteStatus.Unavailable,
            SurfaceTemperatureSection r => r.Status == SatelliteStatus.Unavailable,
            EvapotranspirationSection r => r.Status == SatelliteStatus.Unavailable,
            _ => false,
        };
        memory.Set(key, result, failed ? TimeSpan.FromMinutes(2) : ResponseTtl);
        return result;
    }

    private static (double Lat, double Lon) Round(double lat, double lon) =>
        (Math.Round(lat, 3, MidpointRounding.AwayFromZero), Math.Round(lon, 3, MidpointRounding.AwayFromZero));

    private async Task<T> Safe<T>(Func<Task<T>> load, Func<string, T> failed)
    {
        try
        {
            return await load();
        }
        catch (Exception ex) when (ex is HttpRequestException or OperationCanceledException or JsonException
            or TimeoutException or FormatException or Polly.Timeout.TimeoutRejectedException
            or Polly.CircuitBreaker.BrokenCircuitException)
        {
            logger.LogWarning(ex, "NASA MODIS (ORNL DAAC) section failed");
            return failed(SatelliteStatus.Unavailable);
        }
    }

    // ------------------------------------------------------------------ sections

    private async Task<VegetationSection> VegetationAsync(double lat, double lon, CancellationToken ct)
    {
        const string product = "MOD13Q1";
        var dates = await DatesAsync(product, lat, lon, ct);
        if (dates.Count == 0)
        {
            return new VegetationSection(SatelliteStatus.NoData, NdviSource, 250, 0, null, null, null, []);
        }

        var year = dates[^1].Date.Year;
        var current = dates.Where(d => d.Date.Year == year).ToList();
        var (now, history, years) = await ReadAsync(product, "250m_16_days_NDVI", lat, lon, dates, current, ct);
        var season = SatelliteMath.WithNormals(
            now.Select(p => (p.Date, SatelliteMath.Ndvi(p.Raw))),
            history.Select(p => (p.Date, SatelliteMath.Ndvi(p.Raw))));
        var latest = SatelliteMath.Latest(season);
        if (latest is null)
        {
            return new VegetationSection(SatelliteStatus.NoData, NdviSource, 250, years, null, null, null, season);
        }

        string? reliability = null;
        var latestDate = current.First(d => d.Date == latest.Date);
        var flags = await BandAsync(product, "250m_16_days_pixel_reliability", lat, lon, [latestDate], ct);
        if (flags.TryGetValue(latest.Date, out var flag))
        {
            reliability = SatelliteMath.Reliability(flag);
        }

        return new VegetationSection(SatelliteStatus.Ok, NdviSource, 250, years, latest,
            SatelliteMath.NdviLevel(latest), reliability, season);
    }

    private async Task<SurfaceTemperatureSection> TemperatureAsync(double lat, double lon, CancellationToken ct)
    {
        const string product = "MOD11A2";
        var dates = await DatesAsync(product, lat, lon, ct);
        if (dates.Count == 0)
        {
            return new SurfaceTemperatureSection(SatelliteStatus.NoData, LstSource, 1000, 0, null, null, null, null, null, false);
        }

        var current = dates.TakeLast(RecentComposites).ToList();
        var dayTask = ReadAsync(product, "LST_Day_1km", lat, lon, dates, current, ct);
        var nightTask = ReadAsync(product, "LST_Night_1km", lat, lon, dates, current, ct);
        var (dayNow, dayHistory, dayYears) = await dayTask;
        var (nightNow, nightHistory, _) = await nightTask;

        var day = SatelliteMath.WithNormals(
            dayNow.Select(p => (p.Date, SatelliteMath.LstCelsius(p.Raw))),
            dayHistory.Select(p => (p.Date, SatelliteMath.LstCelsius(p.Raw))));
        var night = SatelliteMath.WithNormals(
            nightNow.Select(p => (p.Date, SatelliteMath.LstCelsius(p.Raw))),
            nightHistory.Select(p => (p.Date, SatelliteMath.LstCelsius(p.Raw))));

        // The newest composite with a day or a night value (clouds often hide one of them).
        var date = current.Select(d => d.Date).LastOrDefault(d =>
            day.Any(p => p.Date == d && p.Value is not null) || night.Any(p => p.Date == d && p.Value is not null));
        if (date == default)
        {
            return new SurfaceTemperatureSection(SatelliteStatus.NoData, LstSource, 1000, dayYears, null, null, null, null, null, false);
        }

        var d = day.FirstOrDefault(p => p.Date == date);
        var n = night.FirstOrDefault(p => p.Date == date);
        return new SurfaceTemperatureSection(SatelliteStatus.Ok, LstSource, 1000, dayYears, date,
            Round(d?.Value, 1), Round(n?.Value, 1), Round(d?.Normal, 1), Round(n?.Normal, 1),
            n?.Value is < 0);
    }

    private async Task<EvapotranspirationSection> EvapotranspirationAsync(double lat, double lon, CancellationToken ct)
    {
        const string product = "MOD16A2";
        var dates = await DatesAsync(product, lat, lon, ct);
        if (dates.Count == 0)
        {
            return new EvapotranspirationSection(SatelliteStatus.NoData, EtSource, 500, 0, null, null);
        }

        var current = dates.TakeLast(RecentComposites).ToList();
        var (now, history, years) = await ReadAsync(product, "ET_500m", lat, lon, dates, current, ct);
        var points = SatelliteMath.WithNormals(
            now.Select(p => (p.Date, SatelliteMath.EtMmPerDay(p.Raw))),
            history.Select(p => (p.Date, SatelliteMath.EtMmPerDay(p.Raw))));
        var latest = SatelliteMath.Latest(points);
        if (latest is null)
        {
            return new EvapotranspirationSection(SatelliteStatus.NoData, EtSource, 500, years, null, null);
        }

        var rounded = latest with { Value = Round(latest.Value, 2), Normal = Round(latest.Normal, 2) };
        return new EvapotranspirationSection(SatelliteStatus.Ok, EtSource, 500, years, rounded,
            SatelliteMath.EtLevel(latest));
    }

    // ------------------------------------------------------------------ reading

    /// <summary>
    /// <paramref name="current"/> composites of <paramref name="band"/> and the same days of the year in the
    /// previous <see cref="NormalYears"/> years; how many of those years had a value.
    /// </summary>
    private async Task<(List<(DateOnly Date, int Raw)> Now, List<(DateOnly Date, int Raw)> History, int Years)> ReadAsync(
        string product, string band, double lat, double lon,
        IReadOnlyList<ModisDate> all, IReadOnlyList<ModisDate> current, CancellationToken ct)
    {
        var groups = new List<IReadOnlyList<ModisDate>> { current };
        for (var k = 1; k <= NormalYears; k++)
        {
            var wanted = current.Select(d => (d.Date.Year - k, d.DayOfYear)).ToHashSet();
            var past = all.Where(d => wanted.Contains((d.Date.Year, d.DayOfYear))).ToList();
            if (past.Count > 0)
            {
                groups.Add(past);
            }
        }

        var results = await Task.WhenAll(groups.Select(g => BandAsync(product, band, lat, lon, g, ct)));
        var now = results[0].Select(kv => (kv.Key, kv.Value)).ToList();
        var history = results.Skip(1).SelectMany(r => r.Select(kv => (kv.Key, kv.Value))).ToList();
        var years = results.Skip(1).Count(r => r.Count > 0);
        return (now, history, years);
    }

    /// <summary>Raw values of consecutive composites of one band, from the store or from ORNL (then stored).</summary>
    private async Task<IReadOnlyDictionary<DateOnly, int>> BandAsync(
        string product, string band, double lat, double lon, IReadOnlyList<ModisDate> dates, CancellationToken ct)
    {
        var key = string.Create(CultureInfo.InvariantCulture,
            $"subset:{product}:{band}:{lat:F3}:{lon:F3}:{dates[0].Code}:{dates[^1].Code}");
        var now = time.GetUtcNow();
        if (await store.GetAsync(Provider, key, now, ct) is { Json: { } json }
            && JsonSerializer.Deserialize<Dictionary<DateOnly, int>>(json) is { } stored)
        {
            return stored;
        }

        IReadOnlyDictionary<DateOnly, int> values;
        await Slots.WaitAsync(ct);
        try
        {
            values = await ornl.GetSubsetAsync(product, band, lat, lon, dates, ct);
        }
        finally
        {
            Slots.Release();
        }

        var pastYear = dates[^1].Date.Year < DateOnly.FromDateTime(now.UtcDateTime).Year;
        await store.SetAsync(Provider, key, JsonSerializer.Serialize(values), now,
            now + (pastYear ? PastYearTtl : CurrentYearTtl), ct);
        return values;
    }

    /// <summary>Composites of the product at the point (stored for a day).</summary>
    private async Task<IReadOnlyList<ModisDate>> DatesAsync(string product, double lat, double lon, CancellationToken ct)
    {
        var key = string.Create(CultureInfo.InvariantCulture, $"dates:{product}:{lat:F3}:{lon:F3}");
        var now = time.GetUtcNow();
        if (await store.GetAsync(Provider, key, now, ct) is { Json: { } json }
            && JsonSerializer.Deserialize<List<ModisDate>>(json) is { } stored)
        {
            return stored;
        }

        IReadOnlyList<ModisDate> dates;
        await Slots.WaitAsync(ct);
        try
        {
            dates = await ornl.GetDatesAsync(product, lat, lon, ct);
        }
        finally
        {
            Slots.Release();
        }

        await store.SetAsync(Provider, key, JsonSerializer.Serialize(dates), now, now + DatesTtl, ct);
        return dates;
    }

    private static double? Round(double? value, int decimals) =>
        value is { } v ? Math.Round(v, decimals, MidpointRounding.AwayFromZero) : null;
}
