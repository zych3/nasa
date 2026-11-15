using FieldShift.Web.Weather;

namespace TestProject1;

public class FrostRiskServiceTests
{
    private static string Forecast(params double?[] mins) =>
        "{\"daily\":{\"time\":[" +
        string.Join(",", mins.Select((_, i) => $"\"2026-11-{16 + i}\"")) +
        "],\"temperature_2m_min\":[" +
        string.Join(",", mins.Select(m => m is null ? "null" : m.Value.ToString(System.Globalization.CultureInfo.InvariantCulture))) +
        "]}}";

    [Fact]
    public void Warm_week_has_no_risk()
    {
        var r = FrostRiskService.Evaluate(Forecast(5, 7.5, 3.1));
        Assert.Equal("none", r.Risk);
        Assert.Null(r.Date);
    }

    [Fact]
    public void Minimum_below_zero_is_frost_on_the_coldest_day()
    {
        var r = FrostRiskService.Evaluate(Forecast(4, -1, -3.5, 1));
        Assert.Equal("frost", r.Risk);
        Assert.Equal(new DateOnly(2026, 11, 18), r.Date);
        Assert.Equal(-3.5, r.MinTemperatureC);
    }

    [Fact]
    public void Minimum_just_above_zero_is_light_frost()
    {
        var r = FrostRiskService.Evaluate(Forecast(6, 1.5));
        Assert.Equal("light", r.Risk);
        Assert.Equal(1.5, r.MinTemperatureC);
    }

    [Fact]
    public void Missing_values_are_skipped()
    {
        var r = FrostRiskService.Evaluate(Forecast(null, -2));
        Assert.Equal("frost", r.Risk);
    }
}
