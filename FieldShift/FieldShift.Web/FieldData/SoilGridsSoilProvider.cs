using System.Globalization;
using FieldShift.Web.FieldProfile;

namespace FieldShift.Web.FieldData;

/// <summary>
/// Topsoil composition from ISRIC SoilGrids v2.0 (modelled, about 250 m, worldwide). The point is rounded to
/// 0.01° (about 1 km) for the request and the cache key, as the field profile and map layers always did.
/// SoilGrids is slow and allows few requests per minute, and its model rarely changes, so results are kept long.
/// </summary>
public sealed class SoilGridsSoilProvider(SoilGridsClient client) : ISoilPropertiesProvider
{
    public string Id => "soilgrids.v2";

    public TimeSpan CacheFor => TimeSpan.FromDays(180);

    public bool Supports(FieldLocation location) => true;

    public string CacheKey(FieldLocation location)
    {
        var (lat, lon) = Round(location);
        return string.Create(CultureInfo.InvariantCulture, $"{lat:F2},{lon:F2}");
    }

    public async Task<SoilGridsData?> GetAsync(FieldLocation location, CancellationToken ct)
    {
        var (lat, lon) = Round(location);
        return await client.GetTopsoilAsync(lat, lon, ct);
    }

    private static (double Lat, double Lon) Round(FieldLocation location) =>
        (Math.Round(location.Lat, 2, MidpointRounding.AwayFromZero),
         Math.Round(location.Lon, 2, MidpointRounding.AwayFromZero));
}
