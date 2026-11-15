using System.Globalization;
using System.Text.Json;

namespace FieldShift.Web.Satellite;

/// <summary>One composite of a MODIS product: its MODIS date code ("A2025161") and calendar date.</summary>
public sealed record ModisDate(string Code, DateOnly Date)
{
    /// <summary>Day of the year of the composite's first day; composites repeat on the same days every year.</summary>
    public int DayOfYear => Date.DayOfYear;
}

/// <summary>
/// NASA ORNL DAAC "MODIS/VIIRS Land Product Subsets" web service (no login): values of one pixel of a MODIS product
/// at a point. https://modis.ornl.gov/data/modis_webservice.html
/// </summary>
public sealed class OrnlModisClient(HttpClient http)
{
    /// <summary>The service answers at most this many composites per subset request.</summary>
    public const int MaxDatesPerRequest = 10;

    /// <summary>Every composite the product has at the point, oldest first; empty where it has no data.</summary>
    public async Task<IReadOnlyList<ModisDate>> GetDatesAsync(string product, double lat, double lon, CancellationToken ct)
    {
        using var response = await http.GetAsync(
            string.Create(CultureInfo.InvariantCulture, $"{product}/dates?latitude={lat}&longitude={lon}"), ct);
        response.EnsureSuccessStatusCode();
        return ParseDates(await response.Content.ReadAsStringAsync(ct));
    }

    /// <summary>
    /// Raw (unscaled) values of <paramref name="band"/> for the given composites (consecutive, oldest first), split
    /// into requests of <see cref="MaxDatesPerRequest"/>. A composite without a value is left out.
    /// </summary>
    public async Task<IReadOnlyDictionary<DateOnly, int>> GetSubsetAsync(
        string product, string band, double lat, double lon, IReadOnlyList<ModisDate> dates, CancellationToken ct)
    {
        var result = new Dictionary<DateOnly, int>();
        foreach (var chunk in dates.Chunk(MaxDatesPerRequest))
        {
            using var response = await http.GetAsync(string.Create(CultureInfo.InvariantCulture,
                $"{product}/subset?latitude={lat}&longitude={lon}&band={band}&startDate={chunk[0].Code}&endDate={chunk[^1].Code}&kmAboveBelow=0&kmLeftRight=0"),
                ct);
            response.EnsureSuccessStatusCode();
            foreach (var (date, value) in ParseSubset(await response.Content.ReadAsStringAsync(ct)))
            {
                result[date] = value;
            }
        }

        return result;
    }

    /// <summary>Parses <c>/dates</c>; the service answers a JSON string (not an object) where it has no data.</summary>
    public static IReadOnlyList<ModisDate> ParseDates(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.ValueKind != JsonValueKind.Object
            || !doc.RootElement.TryGetProperty("dates", out var dates)
            || dates.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        var list = new List<ModisDate>();
        foreach (var d in dates.EnumerateArray())
        {
            if (d.TryGetProperty("modis_date", out var code) && code.GetString() is { } c
                && d.TryGetProperty("calendar_date", out var cal)
                && DateOnly.TryParseExact(cal.GetString(), "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var date))
            {
                list.Add(new ModisDate(c, date));
            }
        }

        return list.OrderBy(d => d.Date).ToList();
    }

    /// <summary>Parses <c>/subset</c> for one pixel: (calendar date, raw value).</summary>
    public static IEnumerable<(DateOnly Date, int Value)> ParseSubset(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("subset", out var subset) || subset.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        var list = new List<(DateOnly, int)>();
        foreach (var item in subset.EnumerateArray())
        {
            if (item.TryGetProperty("calendar_date", out var cal)
                && DateOnly.TryParseExact(cal.GetString(), "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var date)
                && item.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Array
                && data.GetArrayLength() > 0 && data[0].TryGetInt32(out var value))
            {
                list.Add((date, value));
            }
        }

        return list;
    }
}
