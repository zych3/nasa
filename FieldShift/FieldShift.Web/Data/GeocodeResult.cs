using System.Globalization;
using System.Xml.Linq;

namespace FieldShift.Web.Data;

public sealed record GeocodeResult(
    string? Street,
    string? Municipality,
    string? CountryCode,
    double Latitude,
    double Longitude,
    double? Accuracy);

public static class GeocodeParser
{
    private static readonly XNamespace Xls = "http://www.opengis.net/xls";
    private static readonly XNamespace Gml = "http://www.opengis.net/gml";

    public static GeocodeResult? Parse(string xml)
    {
        var hit = XDocument.Parse(xml)
            .Descendants(Xls + "GeocodedAddress")
            .FirstOrDefault();

        var pos = hit?.Element(Gml + "Point")?
            .Element(Gml + "pos")
            ?.Value
            .Split(' ', StringSplitOptions.RemoveEmptyEntries);
        
        if (pos is not { Length: 2 })
        {
            return null;
        }

        var addr = hit?.Element(Xls + "Address");

        return new GeocodeResult(
            Street:       addr?.Element(Xls + "StreetAddress")?.Element(Xls + "Street")?.Value,
            Municipality: Place("Municipality"),
            CountryCode:  (string?)addr?.Attribute("countryCode"),
            Latitude:     double.Parse(pos[1], CultureInfo.InvariantCulture),
            Longitude:    double.Parse(pos[0], CultureInfo.InvariantCulture),
            Accuracy:     (double?)hit?.Element(Xls + "GeocodeMatchCode")?.Attribute("accuracy"));

        string? Place(string type) => addr?
            .Elements(Xls + "Place")
            .FirstOrDefault(p => (string?)p.Attribute("type") == type)?.Value;
    }
}