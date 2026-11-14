using FieldShift.Web.Data;

namespace FieldShift.Web.Countries;

public interface ICountryProvider
{
    public Task<GeocodeResult?> GetGeocodeAsync(string address);

    public Task<ParcelResult?> GetParcelAsync(GeocodeResult location);

    /// <summary>
    /// Address points closest to a coordinate, nearest first.
    /// Returns an empty list when the country has no reverse geocoding.
    /// </summary>
    public Task<IReadOnlyList<GeocodeResult>> GetNearbyAddressesAsync(
        double latitude, double longitude, int limit, int radiusMeters);
}
