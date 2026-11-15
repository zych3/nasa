using System.Globalization;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Tiles of the Polish soil-agricultural map (agricultural suitability complexes) from GUGiK's WMS, the same
/// service as <see cref="SoilAgriculturalMapProvider"/>, drawn in Web Mercator for the app's map. The colours are
/// the service's own; <see cref="Legend"/> repeats them (read from its GetLegendGraphic image) with the words.
/// </summary>
public sealed class SoilMapTileProvider(HttpClient http) : IMapTileProvider
{
    public const string Layer = "soil-map";

    private const string SoilContoursLayer = "0";

    public string LayerId => Layer;

    /// <summary>Further out the service draws nothing (the map is 1:5000).</summary>
    public int MinZoom => 13;

    public int MaxZoom => 19;

    public TimeSpan CacheFor => TimeSpan.FromDays(30);

    /// <summary>Solid colours of the service's legend (hatched areas such as forests have no single colour).</summary>
    public IReadOnlyList<MapLegendItem> Legend { get; } =
    [
        Item("1", "#732600"), Item("2", "#D3715B"), Item("3", "#FAC1A2"), Item("4", "#FE6B00"),
        Item("5", "#FEBE00"), Item("6", "#FEFA00"), Item("7", "#FEF680"), Item("8", "#004C73"),
        Item("9", "#1482FF"), Item("10", "#A80084"), Item("11", "#C500FF"), Item("12", "#DF73FF"),
        Item("13", "#E8BEFF"), Item("14", "#EECCFF"), Item("1z", "#4C7300"), Item("2z", "#88C31F"),
        Item("3z", "#C7EE98"), Item("N", "#D2D2D2"), Item("W", "#BDEBFE"),
    ];

    /// <summary>Poland's bounding box, with a margin.</summary>
    public bool Covers(TileAddress tile)
    {
        var (west, south, east, north) = tile.Bounds;
        return east > 14.0 && west < 24.3 && north > 48.9 && south < 55.0;
    }

    public async Task<byte[]> GetTileAsync(TileAddress tile, CancellationToken ct)
    {
        var (w, s, e, n) = tile.MercatorBounds;
        var query = string.Create(CultureInfo.InvariantCulture,
            $"?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&LAYERS={SoilContoursLayer}&STYLES=&SRS=EPSG:3857" +
            $"&BBOX={w:F2},{s:F2},{e:F2},{n:F2}&WIDTH=256&HEIGHT=256&FORMAT=image/png&TRANSPARENT=TRUE");
        using var response = await http.GetAsync(query, ct);
        response.EnsureSuccessStatusCode();
        // A WMS reports errors as XML with status 200.
        if (response.Content.Headers.ContentType?.MediaType != "image/png")
        {
            throw new HttpRequestException(
                $"Soil map WMS answered {response.Content.Headers.ContentType?.MediaType} instead of a PNG.");
        }

        return await response.Content.ReadAsByteArrayAsync(ct);
    }

    private static MapLegendItem Item(string code, string color) =>
        new(code, SoilComplexes.ComplexName(code) ?? code, color);
}
