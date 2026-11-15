using System.Globalization;
using System.Text.Json;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Town / village names by prefix ("Wielic" -> Wieliczka), from Photon (OpenStreetMap data).
/// Used only while the user is still typing the place name, which UUG cannot match by prefix.
/// </summary>
public class PhotonPlaceSearchService(HttpClient http)
{
    /// <summary>Roughly Poland, so places abroad are not suggested.</summary>
    private const string PolandBbox = "14.1,49.0,24.2,54.9";

    private static readonly string[] PlaceTags =
        ["place:city", "place:town", "place:village", "place:hamlet"];

    public async Task<IReadOnlyList<AddressSuggestion>> Search(string text, int limit, CancellationToken ct = default)
    {
        var tags = string.Concat(PlaceTags.Select(t => $"&osm_tag={t}"));
        var res = await http.GetAsync(
            $"api/?q={Uri.EscapeDataString(text.Trim())}&limit={limit}&lang=default&bbox={PolandBbox}{tags}", ct);
        res.EnsureSuccessStatusCode();
        return Parse(await res.Content.ReadAsStringAsync(ct));
    }

    /// <summary>Parses Photon GeoJSON; keeps Polish places only.</summary>
    public static IReadOnlyList<AddressSuggestion> Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("features", out var features) ||
            features.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        var list = new List<AddressSuggestion>();
        foreach (var f in features.EnumerateArray())
        {
            if (!f.TryGetProperty("properties", out var p) ||
                Str(p, "countrycode") is not "PL" ||
                Str(p, "name") is not { } name ||
                !f.TryGetProperty("geometry", out var g) ||
                !g.TryGetProperty("coordinates", out var c) ||
                c.ValueKind != JsonValueKind.Array || c.GetArrayLength() < 2)
            {
                continue;
            }

            var area = new[] { Strip(Str(p, "county"), "powiat "), Strip(Str(p, "state"), "województwo ") }
                .Where(n => !string.IsNullOrWhiteSpace(n)).Select(n => n!).ToList();

            list.Add(new AddressSuggestion(
                AddressSuggestionKind.Place, name, null, null, null, area,
                c[1].GetDouble(), c[0].GetDouble()));
        }

        return list;
    }

    /// <summary>"powiat wielicki" -> "wielicki", to match the UUG names.</summary>
    private static string? Strip(string? value, string prefix) =>
        value is not null && value.StartsWith(prefix, StringComparison.Ordinal) ? value[prefix.Length..] : value;

    private static string? Str(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
}