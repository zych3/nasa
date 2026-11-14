using System.Text.Json;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries;

/// <summary>
/// Polish/English labels, the Wikipedia photo (Wikidata P18, hosted on Wikimedia Commons) and Wikipedia
/// article links per Wikidata item, from the public SPARQL endpoint.
/// </summary>
public sealed class WikidataCropInfoProvider(HttpClient http)
{
    public const int ThumbnailWidth = 330;

    public async Task<IReadOnlyDictionary<string, WikidataInfo>> GetAsync(IEnumerable<string> itemIds, CancellationToken ct)
    {
        var values = string.Join(' ', itemIds.Distinct().Select(id => $"wd:{id}"));
        var query = $$"""
            SELECT ?item ?image ?labelPl ?labelEn ?wikiPl ?wikiEn WHERE {
              VALUES ?item { {{values}} }
              OPTIONAL { ?item wdt:P18 ?image }
              OPTIONAL { ?item rdfs:label ?labelPl FILTER(LANG(?labelPl) = "pl") }
              OPTIONAL { ?item rdfs:label ?labelEn FILTER(LANG(?labelEn) = "en") }
              OPTIONAL { ?wikiPl schema:about ?item; schema:isPartOf <https://pl.wikipedia.org/> }
              OPTIONAL { ?wikiEn schema:about ?item; schema:isPartOf <https://en.wikipedia.org/> }
            }
            """;

        using var request = new HttpRequestMessage(HttpMethod.Post, "")
        {
            Content = new FormUrlEncodedContent([new("query", query)]),
        };
        request.Headers.Accept.ParseAdd("application/sparql-results+json");
        using var response = await http.SendAsync(request, ct);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
        return Parse(doc.RootElement);
    }

    /// <summary>
    /// Groups SPARQL result rows per item. When an item has several photos, a non-SVG one is preferred
    /// (alphabetically first, so the choice is stable).
    /// </summary>
    public static Dictionary<string, WikidataInfo> Parse(JsonElement root)
    {
        static string? Get(JsonElement b, string name) =>
            b.TryGetProperty(name, out var v) ? v.GetProperty("value").GetString() : null;

        return root.GetProperty("results").GetProperty("bindings").EnumerateArray()
            .GroupBy(b => Get(b, "item")!.Split('/')[^1])
            .ToDictionary(g => g.Key, g =>
            {
                var image = g.Select(b => Get(b, "image")).OfType<string>().Distinct()
                    .OrderBy(i => i.EndsWith(".svg", StringComparison.OrdinalIgnoreCase))
                    .ThenBy(i => i, StringComparer.Ordinal)
                    .FirstOrDefault();
                string? First(string name) => g.Select(b => Get(b, name)).FirstOrDefault(v => v is not null);
                return new WikidataInfo(g.Key, First("labelPl"), First("labelEn"), Thumbnail(image),
                    First("wikiPl"), First("wikiEn"));
            });
    }

    /// <summary>Commons "Special:FilePath" link → https thumbnail of <see cref="ThumbnailWidth"/> px.</summary>
    public static string? Thumbnail(string? filePathUrl) =>
        filePathUrl is null
            ? null
            : $"{filePathUrl.Replace("http://", "https://", StringComparison.Ordinal)}?width={ThumbnailWidth}";
}
