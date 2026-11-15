using System.Globalization;
using FieldShift.Web.Data;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries.Poland;

/// <summary>A parcel from ULDK: id, place names (voivodeship, county, commune, precinct) and outline.</summary>
public sealed record UldkParcel(string Id, IReadOnlyList<string> Place, IReadOnlyList<LocalPoint> Ring);

/// <summary>GUGiK ULDK (parcel locator): parcels by point or by id. Answers are plain text, "0" = found.</summary>
public class UldkService(HttpClient http)
{
    /// <summary>Polish national grid (PL-1992), metres; GUGiK services use it.</summary>
    public const int Pl1992 = 2180;

    private const string Details = "id,voivodeship,county,commune,region,geom_wkt";

    public async Task<ParcelResult?> GetParcelByXy(double latitude, double longitude)
    {
        var xy = string.Create(CultureInfo.InvariantCulture, $"{longitude},{latitude},4326");
        var res = await http.GetAsync($"?request=GetParcelByXY&xy={xy}&result=id,geom_wkt&srid=4326");
        res.EnsureSuccessStatusCode();
        var content = await res.Content.ReadAsStringAsync();
        return ParseParcelResult(content);
    }

    /// <summary>The parcel at a WGS84 point, outline in <paramref name="srid"/>; null where there is none.</summary>
    public Task<UldkParcel?> GetParcelAtAsync(double latitude, double longitude, int srid, CancellationToken ct)
    {
        var xy = string.Create(CultureInfo.InvariantCulture, $"{longitude},{latitude},4326");
        return GetDetailsAsync($"?request=GetParcelByXY&xy={xy}&result={Details}&srid={srid}", ct);
    }

    /// <summary>The parcel with this id (e.g. "141205_2.0008.60"), outline in <paramref name="srid"/>.</summary>
    public Task<UldkParcel?> GetParcelByIdAsync(string id, int srid, CancellationToken ct) =>
        GetDetailsAsync($"?request=GetParcelById&id={Uri.EscapeDataString(id)}&result={Details}&srid={srid}", ct);

    private async Task<UldkParcel?> GetDetailsAsync(string query, CancellationToken ct)
    {
        using var res = await http.GetAsync(query, ct);
        res.EnsureSuccessStatusCode();
        return ParseParcelDetails(await res.Content.ReadAsStringAsync(ct));
    }

    /// <summary>Parses "0\nid|voivodeship|county|commune|region|geom_wkt"; null for "not found" answers.</summary>
    public static UldkParcel? ParseParcelDetails(string body)
    {
        var lines = body.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (lines.Length < 2 || lines[0] != "0")
        {
            return null;
        }

        var parts = lines[1].Split('|');
        if (parts.Length < 6)
        {
            return null;
        }

        var ring = ParseWktRing(parts[^1]);
        return ring.Count < 3
            ? null
            : new UldkParcel(parts[0], parts[1..^1].Where(p => p.Length > 0).ToList(), ring);
    }

    /// <summary>
    /// Outer ring of the first polygon of a WKT POLYGON / MULTIPOLYGON ("SRID=2180;" prefix allowed), as written:
    /// X then Y.
    /// </summary>
    public static IReadOnlyList<LocalPoint> ParseWktRing(string wkt)
    {
        var start = wkt.IndexOf("((", StringComparison.Ordinal);
        if (start < 0)
        {
            return [];
        }

        start += 2;
        while (start < wkt.Length && wkt[start] == '(')
        {
            start++;
        }

        var end = wkt.IndexOf(')', start);
        if (end < 0)
        {
            return [];
        }

        var points = new List<LocalPoint>();
        foreach (var pair in wkt[start..end].Split(',', StringSplitOptions.TrimEntries))
        {
            var xy = pair.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (xy.Length >= 2
                && double.TryParse(xy[0], NumberStyles.Float, CultureInfo.InvariantCulture, out var x)
                && double.TryParse(xy[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var y))
            {
                points.Add(new LocalPoint(x, y));
            }
        }

        return points;
    }

    private static ParcelResult? ParseParcelResult(string body)
    {
        var lines = body.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (lines.Length < 2 || lines[0] != "0")
        {
            return null;
        }

        var parts = lines[1].Split('|', 2);
        return parts.Length == 2 ? new ParcelResult(parts[0], parts[1]) : null;
    }
}
