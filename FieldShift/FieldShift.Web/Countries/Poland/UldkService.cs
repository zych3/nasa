using System.Globalization;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

public class UldkService(HttpClient http)
{
    public async Task<ParcelResult?> GetParcelByXy(double latitude, double longitude)
    {
        var xy = string.Create(CultureInfo.InvariantCulture, $"{longitude},{latitude},4326");
        var res = await http.GetAsync($"?request=GetParcelByXY&xy={xy}&result=id,geom_wkt&srid=4326");
        res.EnsureSuccessStatusCode();
        var content = await res.Content.ReadAsStringAsync();
        return ParseParcelResult(content);
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
