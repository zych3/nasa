using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

public class PolandCountryProvider(GugikGeocodingService geocoder, UldkService uldk) : ICountryProvider
{
    public Task<GeocodeResult?> GetGeocodeAsync(string address) =>
        geocoder.GetAddressPosition(address);

    public Task<ParcelResult?> GetParcelAsync(GeocodeResult location) =>
        uldk.GetParcelByXy(location.Latitude, location.Longitude);
}
