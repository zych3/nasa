using System.Globalization;
using FieldShift.Web.Countries;
using FieldShift.Web.FieldData.Cache;

namespace FieldShift.Web.FieldData;

/// <summary>
/// Finds registered parcels (by point or by register id) through the countries' parcel registers
/// (<see cref="ICountryProvider"/>, Poland: ULDK), with the answers kept in the PostgreSQL field data cache, so
/// the register is asked once per parcel (or point) and later lookups take milliseconds. "No parcel here" is
/// remembered for a day. Countries are asked in order; the first that knows the parcel answers.
/// </summary>
public sealed class ParcelLookupCache(IEnumerable<ICountryProvider> countries, FieldDataCache cache)
{
    /// <summary>Parcel boundaries change rarely (divisions, mergers).</summary>
    public static readonly TimeSpan CacheFor = TimeSpan.FromDays(30);

    /// <summary>The registered parcel at a point; null where no country has one.</summary>
    public async Task<FieldLocation?> AtAsync(double lat, double lon, CancellationToken ct) =>
        (await cache.GetAsync(new At(countries), new FieldLocation(lat, lon), ct)).Value;

    /// <summary>The parcel with this register id; null when no register knows it.</summary>
    public async Task<FieldLocation?> ByIdAsync(string parcelId, CancellationToken ct) =>
        (await cache.GetAsync(new ById(countries), new FieldLocation(0, 0) { ParcelId = parcelId }, ct)).Value;

    /// <summary>Lookup by point. Key: the point to 5 decimals (about 1 m).</summary>
    private sealed class At(IEnumerable<ICountryProvider> countries) : IFieldDataProvider<FieldLocation>
    {
        public string Id => "parcel-at.v1";
        public TimeSpan CacheFor => ParcelLookupCache.CacheFor;
        public bool Supports(FieldLocation location) => true;

        public string CacheKey(FieldLocation location) =>
            string.Create(CultureInfo.InvariantCulture, $"{location.Lat:F5},{location.Lon:F5}");

        public async Task<FieldLocation?> GetAsync(FieldLocation location, CancellationToken ct)
        {
            foreach (var country in countries)
            {
                if (await country.GetFieldAtAsync(location.Lat, location.Lon, ct) is { } field)
                {
                    return field;
                }
            }

            return null;
        }
    }

    /// <summary>Lookup by register id.</summary>
    private sealed class ById(IEnumerable<ICountryProvider> countries) : IFieldDataProvider<FieldLocation>
    {
        public string Id => "parcel-id.v1";
        public TimeSpan CacheFor => ParcelLookupCache.CacheFor;
        public bool Supports(FieldLocation location) => location.ParcelId is not null;
        public string CacheKey(FieldLocation location) => location.ParcelId!;

        public async Task<FieldLocation?> GetAsync(FieldLocation location, CancellationToken ct)
        {
            foreach (var country in countries)
            {
                if (await country.GetFieldByParcelIdAsync(location.ParcelId!, ct) is { } field)
                {
                    return field;
                }
            }

            return null;
        }
    }
}
