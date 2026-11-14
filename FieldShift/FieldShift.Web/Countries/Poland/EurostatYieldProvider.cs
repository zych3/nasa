using System.Text.Json;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// National area and yield per crop from Eurostat dataset <c>apro_cpsh1</c>
/// ("Crop production in EU standard humidity"), JSON-stat API, no key needed.
/// </summary>
public sealed class EurostatYieldProvider(HttpClient http, TimeProvider time)
{
    public const string Dataset = "apro_cpsh1";
    public const string AreaCode = "AR_THS_HA";
    public const string YieldCode = "YLD_HUMD_EU_T_HA";
    public const string SourceName = "Eurostat apro_cpsh1: crop production in EU standard humidity";
    private const int YearsBack = 6;

    /// <summary>Latest area and yield for each Eurostat crop code, keyed by that code.</summary>
    public async Task<IReadOnlyDictionary<string, CropProduction>> GetAsync(
        string geo, IEnumerable<string> cropCodes, CancellationToken ct)
    {
        var since = time.GetUtcNow().Year - YearsBack;
        var crops = string.Concat(cropCodes.Distinct().Select(c => $"&crops={Uri.EscapeDataString(c)}"));
        var path = $"data/{Dataset}?format=JSON&lang=EN&geo={geo}&sinceTimePeriod={since}" +
                   $"&strucpro={AreaCode}&strucpro={YieldCode}{crops}";

        using var response = await http.GetAsync(path, ct);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: ct);
        return Parse(doc.RootElement);
    }

    /// <summary>Reads a JSON-stat 2.0 response with dimensions crops, strucpro and time.</summary>
    public static Dictionary<string, CropProduction> Parse(JsonElement root)
    {
        var ids = root.GetProperty("id").EnumerateArray().Select(e => e.GetString()!).ToArray();
        var sizes = root.GetProperty("size").EnumerateArray().Select(e => e.GetInt32()).ToArray();
        var strides = new int[sizes.Length];
        for (int i = sizes.Length - 1, s = 1; i >= 0; s *= sizes[i], i--) strides[i] = s;

        Dictionary<string, int> Index(string dim) =>
            root.GetProperty("dimension").GetProperty(dim).GetProperty("category").GetProperty("index")
                .EnumerateObject().ToDictionary(p => p.Name, p => p.Value.GetInt32());

        var values = new Dictionary<int, double>();
        var raw = root.GetProperty("value");
        if (raw.ValueKind == JsonValueKind.Object)
        {
            foreach (var p in raw.EnumerateObject())
                if (p.Value.ValueKind == JsonValueKind.Number) values[int.Parse(p.Name)] = p.Value.GetDouble();
        }
        else
        {
            var i = 0;
            foreach (var v in raw.EnumerateArray())
            {
                if (v.ValueKind == JsonValueKind.Number) values[i] = v.GetDouble();
                i++;
            }
        }

        var crops = Index("crops");
        var strucpro = Index("strucpro");
        var times = Index("time").OrderByDescending(t => t.Key).ToList();
        int Offset(string dim, int pos) => Array.IndexOf(ids, dim) is var d and >= 0 ? strides[d] * pos : 0;

        (int? Year, double? Value) Latest(int cropPos, string code)
        {
            if (!strucpro.TryGetValue(code, out var sp)) return (null, null);
            foreach (var (year, tp) in times)
            {
                var idx = Offset("crops", cropPos) + Offset("strucpro", sp) + Offset("time", tp);
                if (values.TryGetValue(idx, out var v)) return (int.Parse(year), v);
            }
            return (null, null);
        }

        var result = new Dictionary<string, CropProduction>();
        foreach (var (code, pos) in crops)
        {
            var (areaYear, areaThousandHa) = Latest(pos, AreaCode);
            var (yieldYear, yield) = Latest(pos, YieldCode);
            if (areaYear is null && yieldYear is null) continue;
            result[code] = new CropProduction(
                code, areaYear, areaThousandHa is { } a ? Math.Round(a * 1000) : null, yieldYear, yield, SourceName);
        }
        return result;
    }
}
