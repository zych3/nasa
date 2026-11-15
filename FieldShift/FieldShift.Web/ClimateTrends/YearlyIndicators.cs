using FieldShift.Prediction.Engine.Climate;

namespace FieldShift.Web.ClimateTrends;

/// <summary>One day of weather at the point. Any value may be missing.</summary>
public readonly record struct WeatherDay(double? TMin, double? TMax, double? TMean, double? Precipitation);

/// <summary>A yearly indicator: what it is called in the API, its unit and how one year's value is computed.</summary>
public sealed record IndicatorDefinition(string Id, string Unit, int Decimals, Func<YearWeather, double?> Value);

/// <summary>The days of one calendar year at one latitude (the latitude is needed for evaporation).</summary>
public sealed class YearWeather(int year, double latitude, IReadOnlyDictionary<DateOnly, WeatherDay> days)
{
    public int Year { get; } = year;
    public double Latitude { get; } = latitude;

    /// <summary>Days from <paramref name="from"/> to <paramref name="to"/> (inclusive); null when any day is missing.</summary>
    public List<(DateOnly Date, WeatherDay Day)>? Range(DateOnly from, DateOnly to)
    {
        var result = new List<(DateOnly, WeatherDay)>(to.DayNumber - from.DayNumber + 1);
        for (var date = from; date <= to; date = date.AddDays(1))
        {
            if (!days.TryGetValue(date, out var day))
                return null;
            result.Add((date, day));
        }

        return result;
    }

    public List<(DateOnly Date, WeatherDay Day)>? Months(int first, int last) =>
        Range(new DateOnly(Year, first, 1), new DateOnly(Year, last, DateTime.DaysInMonth(Year, last)));
}

/// <summary>
/// Yearly climate indicators that matter to a farm, computed from daily weather. Pure logic.
/// A year gets no value (null) when a needed day is missing, so half-years never bend a trend.
/// </summary>
public static class YearlyIndicators
{
    public const double FrostC = 0;
    public const double HotDayC = 30;
    public const double DryDayMm = 1;
    public const double HeavyRainMm = 20;
    public const double GrowingBaseC = 10;

    private const int SeasonFirstMonth = 4;   // April
    private const int SeasonLastMonth = 9;    // September

    /// <summary>The closed list of indicators the trends are looked for in.</summary>
    public static readonly IReadOnlyList<IndicatorDefinition> All =
    [
        new("frost_free_days", "days", 0, FrostFreeDays),
        new("last_spring_frost", "day_of_year", 0, LastSpringFrost),
        new("first_autumn_frost", "day_of_year", 0, FirstAutumnFrost),
        new("hot_days", "days", 0, HotDays),
        new("max_temperature", "celsius", 1, MaxTemperature),
        new("growing_degree_days", "degree_days", 0, GrowingDegreeDays),
        new("longest_dry_spell", "days", 0, LongestDrySpell),
        new("season_precipitation", "millimetres", 0, SeasonPrecipitation),
        new("water_balance", "millimetres", 0, WaterBalance),
        new("heavy_rain_days", "days", 0, HeavyRainDays),
    ];

    /// <summary>Day of the year of the last night below 0 °C in January–June; null when there was none.</summary>
    public static double? LastSpringFrost(YearWeather y) =>
        FrostDays(y.Months(1, 6)) is { Count: > 0 } frosts ? frosts[^1].DayOfYear : null;

    /// <summary>Day of the year of the first night below 0 °C in July–December; null when there was none.</summary>
    public static double? FirstAutumnFrost(YearWeather y) =>
        FrostDays(y.Months(7, 12)) is { Count: > 0 } frosts ? frosts[0].DayOfYear : null;

    /// <summary>Days between the last spring frost and the first autumn frost.</summary>
    public static double? FrostFreeDays(YearWeather y) =>
        LastSpringFrost(y) is { } last && FirstAutumnFrost(y) is { } first ? first - last - 1 : null;

    public static double? HotDays(YearWeather y) =>
        Values(y.Months(1, 12), d => d.TMax)?.Count(t => t >= HotDayC);

    public static double? MaxTemperature(YearWeather y) => Values(y.Months(1, 12), d => d.TMax)?.Max();

    /// <summary>Warmth for growth: degrees of the daily mean above 10 °C, summed over April–October.</summary>
    public static double? GrowingDegreeDays(YearWeather y) =>
        Values(y.Months(4, 10), d => d.TMean)?.Sum(t => Math.Max(0, t - GrowingBaseC));

    /// <summary>Longest run of days with under 1 mm of rain in April–September.</summary>
    public static double? LongestDrySpell(YearWeather y)
    {
        if (Values(y.Months(SeasonFirstMonth, SeasonLastMonth), d => d.Precipitation) is not { } rain)
            return null;

        int longest = 0, run = 0;
        foreach (var mm in rain)
        {
            run = mm < DryDayMm ? run + 1 : 0;
            longest = Math.Max(longest, run);
        }

        return longest;
    }

    public static double? SeasonPrecipitation(YearWeather y) =>
        Values(y.Months(SeasonFirstMonth, SeasonLastMonth), d => d.Precipitation)?.Sum();

    /// <summary>
    /// Rain minus what plants and soil could evaporate (reference evapotranspiration, Hargreaves–Samani) in
    /// April–September. More negative = drier season.
    /// </summary>
    public static double? WaterBalance(YearWeather y)
    {
        if (y.Months(SeasonFirstMonth, SeasonLastMonth) is not { } days)
            return null;

        double balance = 0;
        foreach (var (date, day) in days)
        {
            if (day is not { TMin: { } tMin, TMax: { } tMax, Precipitation: { } rain })
                return null;
            balance += rain - Et0Calculator.Hargreaves(y.Latitude, date.DayOfYear, tMin, tMax);
        }

        return balance;
    }

    public static double? HeavyRainDays(YearWeather y) =>
        Values(y.Months(1, 12), d => d.Precipitation)?.Count(mm => mm > HeavyRainMm);

    /// <summary>Dates with a night below 0 °C, in order; null when the days or a minimum temperature is missing.</summary>
    private static List<DateOnly>? FrostDays(List<(DateOnly Date, WeatherDay Day)>? days) =>
        days is null || days.Any(d => d.Day.TMin is null)
            ? null
            : days.Where(d => d.Day.TMin < FrostC).Select(d => d.Date).ToList();

    /// <summary>The chosen value of every day; null when the days or any value is missing.</summary>
    private static List<double>? Values(List<(DateOnly Date, WeatherDay Day)>? days, Func<WeatherDay, double?> pick)
    {
        if (days is null)
            return null;

        var values = new List<double>(days.Count);
        foreach (var (_, day) in days)
        {
            if (pick(day) is not { } value)
                return null;
            values.Add(value);
        }

        return values;
    }
}
