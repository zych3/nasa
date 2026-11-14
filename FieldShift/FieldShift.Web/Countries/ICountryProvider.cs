using FieldShift.Web.Data;

namespace FieldShift.Web.Countries;

public interface ICountryProvider
{
    public Task<GeocodeResult?> GetGeocodeAsync(string address);

    public Task<ParcelResult?> GetParcelAsync(GeocodeResult location);
}
