using System.Globalization;
using System.Xml.Linq;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// The soil-agricultural map (mapa glebowo-rolnicza 1:5000) at a Polish parcel: agricultural suitability complex,
/// soil type and texture by depth. GUGiK's national WMS ("Rolnictwo" module of the Geoportal), layer
/// KONTURY_GLEBOWE. Much of the map comes from surveys of the 1960s–70s; the survey date is returned with it.
/// </summary>
public sealed class SoilAgriculturalMapProvider(HttpClient http) : ISoilMapProvider
{
    public const string Source = "Mapa glebowo-rolnicza 1:5000 (PZGiK), przez Geoportal GUGiK";

    private const string SoilContoursLayer = "0";

    private const string Null = "Null";

    public string Id => "pl.mgr.v1";

    /// <summary>The map is updated by voivodeship every few years.</summary>
    public TimeSpan CacheFor => TimeSpan.FromDays(180);

    public bool Supports(FieldLocation location) =>
        location is { CountryCode: PolandCountryProvider.Code, ParcelId: not null, Local.Srid: UldkService.Pl1992 };

    public string CacheKey(FieldLocation location) => location.ParcelId!;

    public async Task<SoilMapInfo?> GetAsync(FieldLocation location, CancellationToken ct)
    {
        var query = GugikWms.FeatureInfoQuery(
            SoilContoursLayer, location.Local!.Inside, "application/vnd.esri.wms_featureinfo_xml");
        using var response = await http.GetAsync(query, ct);
        response.EnsureSuccessStatusCode();
        return Parse(await response.Content.ReadAsStringAsync(ct));
    }

    /// <summary>Reads the ArcGIS feature info XML (FieldName / FieldValue pairs); null where there is no contour.</summary>
    public static SoilMapInfo? Parse(string xml)
    {
        var feature = XDocument.Parse(xml).Descendants()
            .FirstOrDefault(e => e.Name.LocalName == "FeatureInfo");
        if (feature is null)
        {
            return null;
        }

        var fields = feature.Elements()
            .Where(e => e.Name.LocalName == "Field")
            .Select(f => (
                Name: f.Elements().FirstOrDefault(e => e.Name.LocalName == "FieldName")?.Value.Trim(),
                Value: f.Elements().FirstOrDefault(e => e.Name.LocalName == "FieldValue")?.Value.Trim()))
            .Where(f => f.Name is not null)
            .GroupBy(f => f.Name!)
            .ToDictionary(g => g.Key, g => g.First().Value is { Length: > 0 } v && v != Null ? v : null);
        string? Field(string name) => fields.GetValueOrDefault(name);

        var complex = Field("KOMPLEKS");
        var soilType = Field("TYPPODTYP");
        var texture = new List<SoilTexture>();
        for (var i = 1; i <= 5; i++)
        {
            if (Field($"PODLOZE{i}") is { } code)
            {
                texture.Add(new SoilTexture
                {
                    Code = code,
                    Name = SoilComplexes.TextureName(code, soilType),
                    From = i == 1 ? null : SoilComplexes.DepthName(Field($"MIAZSZOSC{i}")),
                });
            }
        }

        if (complex is null && soilType is null && texture.Count == 0)
        {
            return null;
        }

        return new SoilMapInfo
        {
            Source = Source,
            ComplexCode = complex,
            ComplexName = SoilComplexes.ComplexName(complex),
            SoilTypeCode = soilType,
            SoilTypeName = SoilComplexes.SoilTypeName(soilType),
            Texture = texture,
            SurveyedOn = DateOnly.TryParseExact(Field("AKTUALNOSC_NR"), "yyyy-MM-dd",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var surveyed) ? surveyed : null,
        };
    }
}
