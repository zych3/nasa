using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

public class PolandCountryProvider(
    GugikGeocodingService geocoder,
    UldkService uldk,
    UugReverseGeocodingService reverseGeocoder) : ICountryProvider
{
    public Task<GeocodeResult?> GetGeocodeAsync(string address) =>
        geocoder.GetAddressPosition(address);

    public Task<ParcelResult?> GetParcelAsync(GeocodeResult location) =>
        uldk.GetParcelByXy(location.Latitude, location.Longitude);

    public Task<IReadOnlyList<GeocodeResult>> GetNearbyAddressesAsync(
        double latitude, double longitude, int limit, int radiusMeters) =>
        reverseGeocoder.GetNearbyAddresses(latitude, longitude, limit, radiusMeters);
}
