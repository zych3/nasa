using System.Globalization;
using System.Text.Json;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// GUGiK "Usługa Geokodowania" (UUG): nearest address points to a coordinate.
/// </summary>
public class UugReverseGeocodingService(HttpClient http)
{
    public async Task<IReadOnlyList<GeocodeResult>> GetNearbyAddresses(
        double latitude, double longitude, int limit, int radiusMeters)
    {
        var point = string.Create(CultureInfo.InvariantCulture, $"POINT({longitude} {latitude})");
        var res = await http.GetAsync(
            $"?request=GetAddressReverse&location={Uri.EscapeDataString(point)}&srid=4326&radius={radiusMeters}&limit={limit}");
        res.EnsureSuccessStatusCode();
        var content = await res.Content.ReadAsStringAsync();
        return Parse(content);
    }

    /// <summary>Parses the UUG JSON. "results" is an object keyed "1", "2", ... (or null/[] when empty).</summary>
    public static IReadOnlyList<GeocodeResult> Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("results", out var results) ||
            results.ValueKind != JsonValueKind.Object)
        {
            return [];
        }

        var list = new List<GeocodeResult>();
        foreach (var entry in results.EnumerateObject())
        {
            var hit = entry.Value;
            if (!TryDouble(hit, "x", out var x) || !TryDouble(hit, "y", out var y))
            {
                continue;
            }

            var city = Str(hit, "city");
            var street = Str(hit, "street");
            var number = Str(hit, "number");
            // Villages often have no street: the address is "<village> <number>".
            var line = string.Join(' ', new[] { street ?? city, number }.Where(s => !string.IsNullOrEmpty(s)));

            list.Add(new GeocodeResult(
                Street: string.IsNullOrEmpty(line) ? null : line,
                Municipality: city,
                CountryCode: "PL",
                Latitude: y,
                Longitude: x,
                Accuracy: null));
        }

        return list;
    }

    private static string? Str(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    private static bool TryDouble(JsonElement e, string name, out double value)
    {
        value = 0;
        return Str(e, name) is { } s &&
               double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
    }
}
