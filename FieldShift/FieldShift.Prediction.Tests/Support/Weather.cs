using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Tests.Support;

/// <summary>Synthetic weather for tests: simple, hand-checkable patterns.</summary>
public static class Weather
{
    /// <summary>One calendar year where every day has the same values.</summary>
    public static ClimateYear Constant(
        int year, double tMin = 5, double tMax = 15, double precip = 0, double? et0 = null, double? snowCm = null)
    {
        var days = new List<DailyWeather>();
        for (var d = new DateOnly(year, 1, 1); d.Year == year; d = d.AddDays(1))
            days.Add(new DailyWeather(d, tMin, tMax, precip, et0, snowCm));
        return new ClimateYear(year, days);
    }

    public static ClimateData Years(int from, int count, Func<int, ClimateYear> year) =>
        new() { Years = Enumerable.Range(from, count).Select(year).ToList() };

    /// <summary>Same as <paramref name="year"/> but with per-day control.</summary>
    public static ClimateYear Custom(int year, Func<DateOnly, DailyWeather> day)
    {
        var days = new List<DailyWeather>();
        for (var d = new DateOnly(year, 1, 1); d.Year == year; d = d.AddDays(1))
            days.Add(day(d));
        return new ClimateYear(year, days);
    }
}
