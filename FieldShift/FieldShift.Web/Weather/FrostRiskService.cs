using System.Globalization;
using System.Text.Json;
using FieldShift.Web.DTOs;

namespace FieldShift.Web.Weather;

/// <summary>Looks for frost in the 7-day forecast of Open-Meteo (free, no key).</summary>
public sealed class FrostRiskService(HttpClient http)
{
    public const double FrostBelowC = 0;
    public const double LightFrostBelowC = 2;

    public async Task<FrostRiskResponse> GetAsync(double lat, double lon, CancellationToken ct)
    {
        var url = string.Create(CultureInfo.InvariantCulture,
            $"v1/forecast?latitude={lat:0.####}&longitude={lon:0.####}&daily=temperature_2m_min&forecast_days=7&timezone=auto");
        using var response = await http.GetAsync(url, ct);
        response.EnsureSuccessStatusCode();
        return Evaluate(await response.Content.ReadAsStringAsync(ct));
    }

    /// <summary>Picks the coldest day at risk from an Open-Meteo daily forecast.</summary>
    public static FrostRiskResponse Evaluate(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var daily = doc.RootElement.GetProperty("daily");
        var times = daily.GetProperty("time");
        var mins = daily.GetProperty("temperature_2m_min");

        DateOnly? coldDay = null;
        double? coldest = null;
        for (var i = 0; i < Math.Min(times.GetArrayLength(), mins.GetArrayLength()); i++)
        {
            if (mins[i].ValueKind != JsonValueKind.Number) continue;
            var min = mins[i].GetDouble();
            if (min <= LightFrostBelowC && (coldest is null || min < coldest))
            {
                coldest = min;
                coldDay = DateOnly.Parse(times[i].GetString()!, CultureInfo.InvariantCulture);
            }
        }

        if (coldest is not { } t) return new FrostRiskResponse { Risk = "none" };
        return new FrostRiskResponse
        {
            Risk = t <= FrostBelowC ? "frost" : "light",
            Date = coldDay,
            MinTemperatureC = t,
        };
    }
}
