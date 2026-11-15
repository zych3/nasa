using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Tests.Support;

public static class Weather
{
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

    public static ClimateYear Custom(int year, Func<DateOnly, DailyWeather> day)
    {
        var days = new List<DailyWeather>();
        for (var d = new DateOnly(year, 1, 1); d.Year == year; d = d.AddDays(1))
            days.Add(day(d));
        return new ClimateYear(year, days);
    }
}
