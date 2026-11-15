using FieldShift.Web.Data;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries;

public interface ICountryProvider
{
    /// <summary>ISO 3166-1 alpha-2 code, e.g. "PL"; field data providers use it to say what they support.</summary>
    public string CountryCode { get; }

    /// <summary>
    /// The registered parcel at a point, as a <see cref="FieldLocation"/> with the outline in the country's grid;
    /// null when the point is outside the country or not on a parcel.
    /// </summary>
    public Task<FieldLocation?> GetFieldAtAsync(double latitude, double longitude, CancellationToken ct);

    /// <summary>The parcel with this register id; null when there is none.</summary>
    public Task<FieldLocation?> GetFieldByParcelIdAsync(string parcelId, CancellationToken ct);

    public Task<GeocodeResult?> GetGeocodeAsync(string address);

    public Task<ParcelResult?> GetParcelAsync(GeocodeResult location);

    /// <summary>
    /// Address points closest to a coordinate, nearest first.
    /// Returns an empty list when the country has no reverse geocoding.
    /// </summary>
    public Task<IReadOnlyList<GeocodeResult>> GetNearbyAddressesAsync(
        double latitude, double longitude, int limit, int radiusMeters);
}
