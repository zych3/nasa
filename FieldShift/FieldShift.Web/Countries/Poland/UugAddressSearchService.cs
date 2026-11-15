using System.Globalization;
using System.Text.Json;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// GUGiK "Usługa Geokodowania" (UUG) address search. It needs the full town name, then matches
/// street prefixes after a comma ("Wieliczka, Kr") and house numbers ("Wieliczka, Krakowska 1",
/// "Zakrzów 12" for villages without streets).
/// </summary>
public class UugAddressSearchService(HttpClient http)
{
    public async Task<IReadOnlyList<AddressSuggestion>> Search(string text, CancellationToken ct = default)
    {
        // A trailing comma ("Wieliczka, ") makes UUG return nothing.
        var query = text.Trim().TrimEnd(',').Trim();
        if (query.Length == 0) return [];

        var res = await http.GetAsync(
            $"?request=GetAddress&srid=4326&address={Uri.EscapeDataString(query)}", ct);
        res.EnsureSuccessStatusCode();
        var body = await res.Content.ReadAsStringAsync(ct);        // UUG answers some inputs with plain text instead of JSON: treat it as "no hints".
        return body.TrimStart().StartsWith('{') ? Parse(body) : [];
    }

    /// <summary>
    /// Parses the UUG JSON. "type" is "city", "street" or "address"; "results" is an object
    /// keyed "1", "2", ... (or null when empty).
    /// </summary>
    public static IReadOnlyList<AddressSuggestion> Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        if (!root.TryGetProperty("results", out var results) || results.ValueKind != JsonValueKind.Object)
        {
            return [];
        }

        var type = Str(root, "type");
        var list = new List<AddressSuggestion>();
        foreach (var entry in results.EnumerateObject())
        {
            var hit = entry.Value;
            if (!TryDouble(hit, "x", out var x) || !TryDouble(hit, "y", out var y)) continue;

            var city = Str(hit, "city");
            switch (type)
            {
                case "city":
                    list.Add(new AddressSuggestion(
                        AddressSuggestionKind.Place, city, null, null, null,
                        Names(Str(hit, "commune"), Str(hit, "county"), Str(hit, "voivodeship")), y, x));
                    break;
                case "street":
                    list.Add(new AddressSuggestion(
                        AddressSuggestionKind.Street, city, CleanStreet(Str(hit, "street")), null, null,
                        [], y, x));
                    break;
                case "address":
                    list.Add(new AddressSuggestion(
                        AddressSuggestionKind.Address, city, CleanStreet(Str(hit, "street")),
                        Str(hit, "number"), Str(hit, "code"), AreaFromUnit(Str(hit, "jednostka")), y, x));
                    break;
            }
        }

        return list;
    }

    /// <summary>"ulica Marszałkowska" -> "Marszałkowska" (UUG matches the short name, and it reads better).</summary>
    private static string? CleanStreet(string? street) =>
        street is not null && street.StartsWith("ulica ", StringComparison.Ordinal) ? street["ulica ".Length..] : street;

    /// <summary>"{Polska,małopolskie,wielicki,Niepołomice}" -> [Niepołomice, wielicki, małopolskie].</summary>
    private static IReadOnlyList<string> AreaFromUnit(string? unit)
    {
        if (unit is null) return [];
        var parts = unit.Trim('{', '}').Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        // Only the full "{Polska,region,county,commune}" form is useful; "{Warszawa,146501}" is not.
        return parts is ["Polska", ..] ? Names(parts[1..].Reverse().ToArray()) : [];
    }

    private static IReadOnlyList<string> Names(params string?[] names) =>
        names.Where(n => !string.IsNullOrWhiteSpace(n)).Select(n => n!).Distinct().ToList();

    private static string? Str(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    private static bool TryDouble(JsonElement e, string name, out double value)
    {
        value = 0;
        return Str(e, name) is { } s &&
               double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
    }
}
