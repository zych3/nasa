using System.Globalization;
using System.Text.Json;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldData;
using FieldShift.Web.FieldData.Cache;
using FieldShift.Web.FieldProfile;
using Microsoft.Extensions.Caching.Memory;

namespace FieldShift.Web.ClimateTrends;

/// <summary>
/// Trends for a parcel: finds the parcel, fetches the daily weather of its climate grid cell since 1981 from
/// NASA POWER, and fits the advice to what is known about the parcel (soil map, terrain).
/// <para>The weather analysis is cached per grid cell and last year (a finished year never changes). What is
/// known about the parcel comes through the field data cache; when it does not come in time, the advice is the
/// general one: the trends never wait for it.</para>
/// </summary>
public sealed class ClimateTrendsProvider(
    ParcelLookupCache parcels,
    IEnumerable<ISoilMapProvider> soilMaps,
    IEnumerable<ITerrainProvider> terrains,
    FieldDataCache fieldData,
    NasaPowerClient nasa,
    ClimateTrendRules rules,
    IMemoryCache cache,
    TimeProvider time,
    ILogger<ClimateTrendsProvider> log)
{
    /// <summary>NASA POWER daily data (MERRA-2) starts in 1981.</summary>
    public const int FirstYear = 1981;

    /// <summary>The MERRA-2 grid: cell centres at multiples of these steps.</summary>
    public const double GridLatStep = 0.5;

    /// <inheritdoc cref="GridLatStep"/>
    public const double GridLonStep = 0.625;

    private static readonly string[] Parameters = ["T2M", "T2M_MIN", "T2M_MAX", "PRECTOTCORR"];
    private static readonly TimeSpan CacheFor = TimeSpan.FromDays(30);

    /// <summary>The soil map and the terrain model get this long; after that the advice is the general one.</summary>
    private static readonly TimeSpan SiteTimeout = TimeSpan.FromSeconds(8);

    /// <summary>
    /// Trends for the parcel with the given id, or for the parcel at the point. When no parcel is found, the point
    /// alone is used, so the answer never depends on the parcel register.
    /// </summary>
    /// <returns>Null when only a parcel id was given and no such parcel exists.</returns>
    /// <exception cref="UpstreamServiceException">NASA POWER did not answer.</exception>
    public async Task<ClimateTrendsResponse?> GetAsync(string? parcelId, double? lat, double? lon, CancellationToken ct)
    {
        parcelId = string.IsNullOrWhiteSpace(parcelId) ? null : parcelId.Trim();

        var parcel = await FindParcel(parcelId, lat, lon, ct);
        var point = parcel is not null ? (parcel.Lat, parcel.Lon)
            : lat is { } la && lon is { } lo ? (Lat: la, Lon: lo)
            : ((double Lat, double Lon)?)null;
        if (point is not { } p)
            return null;

        var siteTask = parcel is null ? Task.FromResult(SiteConditions.Unknown) : GetSiteAsync(parcel, ct);
        var findings = await GetFindingsAsync(p.Lat, p.Lon, ct);
        var site = await siteTask;

        return ClimateTrendAnalyzer.Build(parcel?.ParcelId, p.Lat, p.Lon, findings, site, rules);
    }

    /// <summary>Centre of the climate grid cell the point lies in.</summary>
    public static (double Lat, double Lon) GridCell(double lat, double lon) =>
        (Math.Round(lat / GridLatStep, MidpointRounding.AwayFromZero) * GridLatStep,
            Math.Round(lon / GridLonStep, MidpointRounding.AwayFromZero) * GridLonStep);

    private async Task<ClimateFindings> GetFindingsAsync(double lat, double lon, CancellationToken ct)
    {
        var toYear = time.GetUtcNow().Year - 1; // the last finished year
        var cell = GridCell(lat, lon);
        var key = string.Create(CultureInfo.InvariantCulture, $"climate-trends:{cell.Lat:F3},{cell.Lon:F3}:{toYear}");
        if (cache.TryGetValue(key, out ClimateFindings? cached) && cached is not null)
            return cached;

        NasaPowerDailyData daily;
        try
        {
            // Asked for the cell centre, so everyone in the cell gets the same series whoever asks first.
            daily = await nasa.GetDailyAsync(
                cell.Lat, cell.Lon, new DateOnly(FirstYear, 1, 1), new DateOnly(toYear, 12, 31), Parameters, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException or FormatException or JsonException
                                       || (ex is OperationCanceledException && !ct.IsCancellationRequested))
        {
            log.LogError(ex, "NASA POWER daily request failed for {Lat},{Lon}", cell.Lat, cell.Lon);
            throw new UpstreamServiceException("NASA POWER", ex);
        }

        var findings = ClimateTrendAnalyzer.Find(ClimateTrendAnalyzer.ToDays(daily), cell.Lat, FirstYear, toYear, rules);
        cache.Set(key, findings, CacheFor);
        return findings;
    }

    private async Task<FieldLocation?> FindParcel(string? parcelId, double? lat, double? lon, CancellationToken ct)
    {
        try
        {
            if (parcelId is not null && await parcels.ByIdAsync(parcelId, ct) is { } byId)
                return byId;
            if (lat is { } la && lon is { } lo)
                return await parcels.AtAsync(la, lo, ct);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            if (lat is null || lon is null)
                throw new UpstreamServiceException("The parcel register", ex);
            log.LogWarning(ex, "Parcel lookup failed; using the point alone");
        }

        return null;
    }

    /// <summary>Soil and slope of the parcel; each is "unknown" when its source fails or is too slow.</summary>
    private async Task<SiteConditions> GetSiteAsync(FieldLocation parcel, CancellationToken ct)
    {
        var soilTask = TryAsync(soilMaps, parcel, ct);
        var terrainTask = TryAsync(terrains, parcel, ct);
        var soil = await soilTask;
        var terrain = await terrainTask;

        return new SiteConditions(
            ClimateTrendAnalyzer.IsLightSoil(soil?.Texture.FirstOrDefault()?.Code, soil?.ComplexCode, rules),
            terrain?.SlopePct);
    }

    private async Task<T?> TryAsync<T>(IEnumerable<IFieldDataProvider<T>> providers, FieldLocation parcel, CancellationToken ct)
        where T : class
    {
        var provider = FieldDataCache.Pick(providers, parcel);
        if (provider is null)
            return null;

        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(SiteTimeout);
        try
        {
            return (await fieldData.GetAsync(provider, parcel, limit.Token)).Value;
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            log.LogWarning(ex, "{Provider} gave nothing for parcel {Parcel}; advice stays general", provider.Id, parcel.ParcelId);
            return null;
        }
    }
}
