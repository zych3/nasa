using FieldShift.Web.Data;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries.Poland;

public class PolandCountryProvider(
    GugikGeocodingService geocoder,
    UldkService uldk,
    UugReverseGeocodingService reverseGeocoder) : ICountryProvider
{
    public const string Code = "PL";

    public string CountryCode => Code;

    public Task<GeocodeResult?> GetGeocodeAsync(string address) =>
        geocoder.GetAddressPosition(address);

    public Task<ParcelResult?> GetParcelAsync(GeocodeResult location) =>
        uldk.GetParcelByXy(location.Latitude, location.Longitude);

    public Task<IReadOnlyList<GeocodeResult>> GetNearbyAddressesAsync(
        double latitude, double longitude, int limit, int radiusMeters) =>
        reverseGeocoder.GetNearbyAddresses(latitude, longitude, limit, radiusMeters);

    /// <summary>The point the user gave is inside the parcel, so it is the WGS84 point of the field.</summary>
    public async Task<FieldLocation?> GetFieldAtAsync(double latitude, double longitude, CancellationToken ct)
    {
        var parcel = await uldk.GetParcelAtAsync(latitude, longitude, UldkService.Pl1992, ct);
        return parcel is null ? null : ToLocation(parcel, latitude, longitude);
    }

    /// <summary>The WGS84 point is an interior point of the outline asked for in WGS84 (a second, fast request).</summary>
    public async Task<FieldLocation?> GetFieldByParcelIdAsync(string parcelId, CancellationToken ct)
    {
        var parcel = await uldk.GetParcelByIdAsync(parcelId, UldkService.Pl1992, ct);
        if (parcel is null)
        {
            return null;
        }

        var wgs84 = await uldk.GetParcelByIdAsync(parcelId, 4326, ct);
        if (wgs84 is null)
        {
            return null;
        }

        // ULDK writes WGS84 as longitude, latitude.
        var inside = LocalGeometry.InteriorPoint(wgs84.Ring);
        return ToLocation(parcel, latitude: inside.Y, longitude: inside.X);
    }

    private static FieldLocation ToLocation(UldkParcel parcel, double latitude, double longitude) =>
        new(latitude, longitude)
        {
            CountryCode = Code,
            ParcelId = parcel.Id,
            Local = LocalGeometry.FromRing(UldkService.Pl1992, parcel.Ring),
        };
}
