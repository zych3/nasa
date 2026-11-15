using FieldShift.Web.Countries;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldData.Cache;
using FieldShift.Web.FieldProfile;

namespace FieldShift.Web.FieldData;

/// <summary>
/// Puts <see cref="ParcelDetailsResponse"/> together: the country whose register has the parcel finds it, then each
/// kind of data comes from the first provider that supports the parcel, all at once, through the cache.
/// Nothing here knows a country: a new country is a new <see cref="ICountryProvider"/> plus its providers.
/// </summary>
public sealed class ParcelDetailsService(
    IEnumerable<ICountryProvider> countries,
    IEnumerable<ILandRegistryProvider> landRegistries,
    IEnumerable<ISoilMapProvider> soilMaps,
    IEnumerable<ITerrainProvider> terrains,
    IEnumerable<ISoilPropertiesProvider> soilProperties,
    FieldDataCache cache,
    TimeProvider time,
    ILogger<ParcelDetailsService> logger)
{
    /// <summary>Details of the parcel at a point; null when no country's register has a parcel there.</summary>
    public async Task<ParcelDetailsResponse?> AtAsync(double lat, double lon, CancellationToken ct)
    {
        foreach (var country in countries)
        {
            if (await country.GetFieldAtAsync(lat, lon, ct) is { } location)
            {
                return await BuildAsync(location, ct);
            }
        }

        return null;
    }

    /// <summary>Details of the parcel with this register id; null when no register knows it.</summary>
    public async Task<ParcelDetailsResponse?> ByIdAsync(string parcelId, CancellationToken ct)
    {
        foreach (var country in countries)
        {
            if (await country.GetFieldByParcelIdAsync(parcelId, ct) is { } location)
            {
                return await BuildAsync(location, ct);
            }
        }

        return null;
    }

    private async Task<ParcelDetailsResponse> BuildAsync(FieldLocation location, CancellationToken ct)
    {
        var registry = SectionAsync(landRegistries, location, ct);
        var soilMap = SectionAsync(soilMaps, location, ct);
        var terrain = SectionAsync(terrains, location, ct);
        var soil = SectionAsync(soilProperties, location, ct);
        await Task.WhenAll(registry, soilMap, terrain, soil);

        // SoilGrids answers raw layers by depth; the response shows them like the field profile does.
        var soilSection = soil.Result;
        var soilProfile = FieldProfileService.BuildSoilProfile(soilSection.Data);

        return new ParcelDetailsResponse
        {
            CountryCode = location.CountryCode ?? "",
            ParcelId = location.ParcelId ?? "",
            Location = new MapLocation { Lat = location.Lat, Lon = location.Lon },
            OutlineAreaHa = location.Local is { } local ? Math.Round(local.AreaM2 / 10_000, 4) : null,
            LandRegistry = registry.Result,
            SoilMap = soilMap.Result,
            Terrain = terrain.Result,
            SoilProperties = new FieldDataSection<SoilProfile>
            {
                Status = soilSection.Status == FieldDataSection<SoilProfile>.Ok && soilProfile is null
                    ? FieldDataSection<SoilProfile>.NoData
                    : soilSection.Status,
                Data = soilProfile,
                Provider = soilSection.Provider,
                FetchedAtUtc = soilSection.FetchedAtUtc,
                FromCache = soilSection.FromCache,
            },
            GeneratedAtUtc = time.GetUtcNow(),
        };
    }

    private async Task<FieldDataSection<T>> SectionAsync<T>(
        IEnumerable<IFieldDataProvider<T>> providers, FieldLocation location, CancellationToken ct)
        where T : class
    {
        var provider = FieldDataCache.Pick(providers, location);
        if (provider is null)
        {
            return new FieldDataSection<T> { Status = FieldDataSection<T>.NotSupported };
        }

        try
        {
            var result = await cache.GetAsync(provider, location, ct);
            return new FieldDataSection<T>
            {
                Status = result.Value is null ? FieldDataSection<T>.NoData : FieldDataSection<T>.Ok,
                Data = result.Value,
                Provider = provider.Id,
                FetchedAtUtc = result.FetchedAt,
                FromCache = result.FromCache,
            };
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning(ex, "{Provider} failed for parcel {Parcel}", provider.Id, location.ParcelId);
            return new FieldDataSection<T> { Status = FieldDataSection<T>.Unavailable, Provider = provider.Id };
        }
    }
}
