using System.Text.Json;
using FieldShift.Web.Countries.Prices;
using FieldShift.Web.Data;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Real purchase prices from GUS Bank Danych Lokalnych (https://bdl.stat.gov.pl/api/v1/), national level.
/// Without an API key GUS allows 100 requests per 15 minutes, so everything is fetched in ~5 batched requests.
/// GUS publishes prices in zł per decitonne (dt); they are converted to PLN per tonne.
/// </summary>
public sealed class GusBdlPriceProvider(HttpClient http) : IPriceProvider
{
    public const string PolandUnitId = "000000000000";
    public const string MonthlySubjectId = "P2967";
    public const string MonthlySourceName = "GUS BDL P2967: average purchase prices of major agricultural products, monthly";
    public const string YearlySourceName = "GUS BDL P1458: average purchase prices of agricultural products, yearly";
    private const int VariablesPerRequest = 50;
    private const int PageSize = 100;

    /// <summary>Product name as GUS writes it (e.g. "... - pszenica za 1 dt") → crops priced by it.</summary>
    /// <summary>Note codes; the frontend translates them (lib/l10n/crop_note_text.dart).</summary>
    public const string OnePriceAllWheat = "one_price_all_wheat";
    public const string OnePriceAllRye = "one_price_all_rye";
    public const string OnePriceAllBarley = "one_price_all_barley";
    public const string GrainMaizePrice = "grain_maize_price";
    public const string YearlyOnly = "yearly_only";

    private static readonly Dictionary<string, (CropId Id, string? NoteCode)[]> MonthlyProducts = new()
    {
        ["pszenica"] = [(new("wheat"), OnePriceAllWheat)],
        ["żyto"] = [(new("rye"), OnePriceAllRye)],
        ["jęczmień"] = [(new("winter_barley"), OnePriceAllBarley), (new("spring_barley"), OnePriceAllBarley)],
        ["pszenżyto"] = [(new("triticale"), null)],
        ["owies"] = [(new("oats"), null)],
        ["kukurydza"] = [(new("maize"), GrainMaizePrice)],
        ["ziemniaki"] = [(new("potato"), null)],
    };

    /// <summary>Crops GUS prices only once a year (subject P1458).</summary>
    private static readonly (int VariableId, CropId Id, string NoteCode)[] YearlyVariables =
    [
        (4868, new("rapeseed"), YearlyOnly),
        (4867, new("sugar_beet"), YearlyOnly),
    ];

    private static readonly string[] MonthNames =
    [
        "styczeń", "luty", "marzec", "kwiecień", "maj", "czerwiec",
        "lipiec", "sierpień", "wrzesień", "październik", "listopad", "grudzień",
    ];

    /// <summary>One GUS variable = one product in one calendar month (all years).</summary>
    public sealed record MonthlyVariable(int VariableId, string Product, int Month);

    public async Task<IReadOnlyDictionary<CropId, PriceHistory>> GetLatestPricesAsync(int count, CancellationToken ct)
    {
        var monthly = new List<MonthlyVariable>();
        for (var page = 0; ; page++)
        {
            using var doc = await GetJsonAsync(
                $"variables?subject-id={MonthlySubjectId}&format=json&page-size={PageSize}&page={page}", ct);
            var results = doc.RootElement.GetProperty("results");
            monthly.AddRange(ParseMonthlyVariables(doc.RootElement).Where(v => MonthlyProducts.ContainsKey(v.Product)));
            if (results.GetArrayLength() < PageSize) break;
        }

        var ids = monthly.Select(v => v.VariableId).Concat(YearlyVariables.Select(v => v.VariableId)).ToList();
        var values = new Dictionary<int, IReadOnlyList<(int Year, decimal Value)>>();
        foreach (var chunk in ids.Chunk(VariablesPerRequest))
        {
            var query = string.Concat(chunk.Select(id => $"&var-id={id}"));
            using var doc = await GetJsonAsync(
                $"data/by-unit/{PolandUnitId}?format=json&page-size={PageSize}{query}", ct);
            foreach (var (id, series) in ParseValues(doc.RootElement))
            {
                values[id] = series;
            }
        }

        var result = new Dictionary<CropId, PriceHistory>();
        foreach (var (product, crops) in MonthlyProducts)
        {
            var points = monthly
                .Where(v => v.Product == product && values.ContainsKey(v.VariableId))
                .SelectMany(v => values[v.VariableId].Select(p => (Date: new DateOnly(p.Year, v.Month, 1), p.Value)));
            var prices = LatestPerTonne(points, count);
            foreach (var (id, note) in crops)
            {
                result[id] = new PriceHistory(id, "PLN", "t", PriceFrequency.Monthly, MonthlySourceName, note, prices);
            }
        }

        foreach (var (variableId, id, note) in YearlyVariables)
        {
            var points = values.GetValueOrDefault(variableId, [])
                .Select(p => (Date: new DateOnly(p.Year, 1, 1), p.Value));
            result[id] = new PriceHistory(id, "PLN", "t", PriceFrequency.Yearly, YearlySourceName, note,
                LatestPerTonne(points, count));
        }

        return result;
    }

    private async Task<JsonDocument> GetJsonAsync(string path, CancellationToken ct)
    {
        using var response = await http.GetAsync(path, ct);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        return await JsonDocument.ParseAsync(stream, cancellationToken: ct);
    }

    /// <summary>Monthly variables of a BDL <c>variables</c> response; quarters and half-years are skipped.</summary>
    public static IEnumerable<MonthlyVariable> ParseMonthlyVariables(JsonElement root)
    {
        foreach (var v in root.GetProperty("results").EnumerateArray())
        {
            var month = Array.IndexOf(MonthNames, v.GetProperty("n1").GetString()?.Trim().ToLowerInvariant()) + 1;
            if (month == 0) continue;
            var product = ProductName(v.GetProperty("n2").GetString() ?? "");
            yield return new MonthlyVariable(v.GetProperty("id").GetInt32(), product, month);
        }
    }

    /// <summary>"ziarno zbóż (bez siewnego) - pszenżyto za 1dt" → "pszenżyto"; "ziemniaki za 1 dt" → "ziemniaki".</summary>
    public static string ProductName(string n2)
    {
        var za = n2.LastIndexOf(" za ", StringComparison.Ordinal);
        var name = za >= 0 ? n2[..za] : n2;
        var dash = name.LastIndexOf(" - ", StringComparison.Ordinal);
        if (dash >= 0) name = name[(dash + 3)..];
        return name.Trim().ToLowerInvariant();
    }

    /// <summary>Values of a BDL <c>data/by-unit</c> response, per variable id. Missing values are skipped.</summary>
    public static Dictionary<int, IReadOnlyList<(int Year, decimal Value)>> ParseValues(JsonElement root)
    {
        var result = new Dictionary<int, IReadOnlyList<(int Year, decimal Value)>>();
        foreach (var r in root.GetProperty("results").EnumerateArray())
        {
            var series = new List<(int, decimal)>();
            foreach (var v in r.GetProperty("values").EnumerateArray())
            {
                if (v.TryGetProperty("val", out var val) && val.ValueKind == JsonValueKind.Number
                    && int.TryParse(v.GetProperty("year").GetString(), out var year))
                {
                    series.Add((year, val.GetDecimal()));
                }
            }
            result[r.GetProperty("id").GetInt32()] = series;
        }
        return result;
    }

    /// <summary>Latest <paramref name="count"/> points, oldest first, converted from zł/dt to PLN/t.</summary>
    public static IReadOnlyList<CropPrice> LatestPerTonne(IEnumerable<(DateOnly Date, decimal Value)> points, int count) =>
        points
            .OrderBy(p => p.Date)
            .TakeLast(count)
            .Select(p => new CropPrice(p.Date, Math.Round(p.Value * 10m, 2)))
            .ToList();
}
