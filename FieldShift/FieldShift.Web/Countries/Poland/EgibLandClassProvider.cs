using System.Globalization;
using System.Xml.Linq;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Land register (EGiB) entry of a Polish parcel: area, place and land classes ("LzrRIVb,RIVb,…"). Asks GUGiK's
/// national EGiB integration (Krajowa Integracja Ewidencji Gruntów), which passes the request on to the county's
/// own service, so a county being down means no data for its parcels for a while (not cached).
/// </summary>
public sealed class EgibLandClassProvider(HttpClient http) : ILandRegistryProvider
{
    public const string Source = "Ewidencja gruntów i budynków (starostwo powiatowe), przez Geoportal GUGiK";

    public string Id => "pl.egib.v1";

    /// <summary>The register changes rarely; a month keeps it fresh enough.</summary>
    public TimeSpan CacheFor => TimeSpan.FromDays(30);

    public bool Supports(FieldLocation location) =>
        location is { CountryCode: PolandCountryProvider.Code, ParcelId: not null, Local.Srid: UldkService.Pl1992 };

    public string CacheKey(FieldLocation location) => location.ParcelId!;

    public async Task<LandRegistryInfo?> GetAsync(FieldLocation location, CancellationToken ct)
    {
        var query = GugikWms.FeatureInfoQuery(
            "dzialki,kontury,uzytki", location.Local!.Inside, "application/vnd.ogc.gml");
        using var response = await http.GetAsync(query, ct);
        response.EnsureSuccessStatusCode();
        return Parse(await response.Content.ReadAsStringAsync(ct), location.ParcelId!);
    }

    /// <summary>
    /// Reads the GML answer: one feature per parcel at the point, attributes by their Polish names. Prefers the
    /// feature of <paramref name="parcelId"/>; null when there is none or the county published neither the area
    /// nor the classes.
    /// </summary>
    public static LandRegistryInfo? Parse(string gml, string parcelId)
    {
        var features = XDocument.Parse(gml).Descendants()
            .Where(e => e.Name.LocalName == "Layer")
            .Select(layer => layer.Elements()
                .Where(e => e.Name.LocalName == "Attribute" && e.Attribute("Name") is not null)
                .GroupBy(e => e.Attribute("Name")!.Value)
                .ToDictionary(g => g.Key, g => g.First().Value.Trim()))
            .Where(attributes => attributes.Count > 0)
            .ToList();
        var feature = features.FirstOrDefault(f => f.GetValueOrDefault("Identyfikator działki") == parcelId)
            ?? features.FirstOrDefault();
        if (feature is null)
        {
            return null;
        }

        // Contours have land use and class; without them the parcel only has land uses (roads, buildings, ...).
        var contours = feature.GetValueOrDefault("Oznaczenie konturu");
        var classes = LandClassCode.ParseList(
            string.IsNullOrWhiteSpace(contours) ? feature.GetValueOrDefault("Oznaczenie użytku") : contours);

        double? area = double.TryParse(
            feature.GetValueOrDefault("Pole pow. w ewidencji gruntów (ha)"),
            NumberStyles.Float, CultureInfo.InvariantCulture, out var ha) ? ha : null;

        // Some counties publish only the parcel's id and place, without area or classes: nothing to show.
        if (classes.Count == 0 && area is null)
        {
            return null;
        }

        return new LandRegistryInfo
        {
            Source = Source,
            AreaHa = area,
            Place = new[] { "Województwo", "Powiat", "Nazwa gminy", "Nazwa obrębu" }
                .Select(feature.GetValueOrDefault)
                .Where(v => !string.IsNullOrWhiteSpace(v))
                .Select(v => v!)
                .ToList(),
            Classes = classes,
            PublishedOn = DateOnly.TryParseExact(
                feature.GetValueOrDefault("Data publikacji danych"), "yyyy-MM-dd",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var published) ? published : null,
        };
    }
}

/// <summary>GetFeatureInfo requests at one point of the PL-1992 grid, for GUGiK's WMS services.</summary>
internal static class GugikWms
{
    /// <summary>
    /// Query string asking <paramref name="layers"/> about the point: a 10 × 10 m map of 11 × 11 pixels with the
    /// point in the middle pixel. WMS 1.1.1, so the box is easting, northing (no axis swap as in 1.3.0).
    /// </summary>
    public static string FeatureInfoQuery(string layers, LocalPoint point, string infoFormat)
    {
        var box = string.Create(CultureInfo.InvariantCulture,
            $"{point.X - 5:F2},{point.Y - 5:F2},{point.X + 5:F2},{point.Y + 5:F2}");
        return $"?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetFeatureInfo&LAYERS={layers}&QUERY_LAYERS={layers}"
            + $"&SRS=EPSG:2180&BBOX={box}&WIDTH=11&HEIGHT=11&X=5&Y=5&INFO_FORMAT={Uri.EscapeDataString(infoFormat)}"
            + "&FEATURE_COUNT=5&STYLES=&FORMAT=image/png";
    }
}
