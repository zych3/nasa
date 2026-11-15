using System.Globalization;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace FieldShift.Web.Satellite.Earthdata;

/// <summary>NASA Earthdata settings (<c>Earthdata:*</c>). The token comes from the environment (<c>Earthdata__Token</c>).</summary>
public sealed class EarthdataOptions
{
    /// <summary>Earthdata Login user token (valid 60 days). Empty: the Earthdata sections answer "notConfigured".</summary>
    public string? Token { get; set; }

    public string CmrBaseUrl { get; set; } = "https://cmr.earthdata.nasa.gov/";

    public string OpendapBaseUrl { get; set; } = "https://opendap.earthdata.nasa.gov/";
}

/// <summary>One file (granule) of a NASA collection, as the CMR catalogue lists it.</summary>
public sealed record Granule(string Title, DateTimeOffset Start, string CollectionId);

/// <summary>
/// NASA Earthdata through the CMR catalogue (which files exist) and the cloud OPeNDAP service (values of one cell of
/// a file, without downloading the file). The token is sent only to the OPeNDAP host.
/// </summary>
public sealed class EarthdataClient(HttpClient http, IOptions<EarthdataOptions> options)
{
    private EarthdataOptions Options => options.Value;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(Options.Token);

    /// <summary>Files of a collection that start in [from, to], newest first.</summary>
    public async Task<IReadOnlyList<Granule>> FindGranulesAsync(
        string shortName, string? version, DateTimeOffset from, DateTimeOffset to, int max, CancellationToken ct)
    {
        var temporal = FormattableString.Invariant(
            $"{from.UtcDateTime:yyyy-MM-ddTHH:mm:ssZ},{to.UtcDateTime:yyyy-MM-ddTHH:mm:ssZ}");
        var url = $"{Options.CmrBaseUrl.TrimEnd('/')}/search/granules.json?short_name={Uri.EscapeDataString(shortName)}"
            + (version is null ? "" : $"&version={Uri.EscapeDataString(version)}")
            + $"&temporal={temporal}&sort_key=-start_date"
            + $"&page_size={Math.Clamp(max, 1, 2000).ToString(CultureInfo.InvariantCulture)}";
        using var response = await http.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        return ParseGranules(await response.Content.ReadAsStringAsync(ct));
    }

    /// <summary>
    /// Values of one cell of a file: <paramref name="constraint"/> is a DAP4 constraint of single values, e.g.
    /// <c>/precipitation[0][2014][1421]</c> (several separated by ';').
    /// </summary>
    public async Task<IReadOnlyDictionary<string, double>> ReadAsync(Granule granule, string constraint, CancellationToken ct)
    {
        if (!IsConfigured)
        {
            throw new InvalidOperationException("Earthdata token is not configured.");
        }

        var url = $"{Options.OpendapBaseUrl.TrimEnd('/')}/collections/{granule.CollectionId}/granules/"
            + $"{Uri.EscapeDataString(granule.Title)}.dap?dap4.ce={EscapeConstraint(constraint)}";
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", Options.Token!.Trim());
        using var response = await http.SendAsync(request, ct);
        response.EnsureSuccessStatusCode();
        return Dap4Reader.Read(await response.Content.ReadAsByteArrayAsync(ct));
    }

    internal static string EscapeConstraint(string constraint) =>
        constraint.Replace("[", "%5B").Replace("]", "%5D").Replace(" ", "");

    public static IReadOnlyList<Granule> ParseGranules(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("feed", out var feed) || !feed.TryGetProperty("entry", out var entries))
        {
            return [];
        }

        var list = new List<Granule>();
        foreach (var e in entries.EnumerateArray())
        {
            if (e.TryGetProperty("title", out var title) && title.GetString() is { } t
                && e.TryGetProperty("collection_concept_id", out var col) && col.GetString() is { } c
                && e.TryGetProperty("time_start", out var start)
                && DateTimeOffset.TryParse(start.GetString(), CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal, out var s))
            {
                list.Add(new Granule(t, s, c));
            }
        }

        return list;
    }
}
