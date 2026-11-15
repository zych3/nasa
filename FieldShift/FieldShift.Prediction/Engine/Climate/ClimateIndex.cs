using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Climate;

public sealed class ClimateIndex
{
    private readonly Dictionary<DateOnly, DailyWeather> _days = [];
    private readonly SortedSet<int> _years = [];

    public ClimateIndex(ClimateData climate, double latitudeDeg)
    {
        foreach (var year in climate.Years)
        {
            _years.Add(year.Year);
            foreach (var day in year.Days)
            {
                var et0 = day.Et0Mm;
                if (et0 is null)
                {
                    et0 = Et0Calculator.Hargreaves(latitudeDeg, day.Date.DayOfYear, day.TMinC, day.TMaxC);
                    Et0EstimatedDays++;
                }
                _days[day.Date] = day with { Et0Mm = et0 };
            }
        }
    }

    public IReadOnlyCollection<int> Years => _years;
    public int DayCount => _days.Count;

    public int Et0EstimatedDays { get; }

    public bool HasYear(int year) => _years.Contains(year);

    public bool TryGet(DateOnly date, out DailyWeather day) => _days.TryGetValue(date, out day);

    public IReadOnlyList<DailyWeather> Range(DateOnly from, DateOnly to)
    {
        var result = new List<DailyWeather>(Math.Max(0, to.DayNumber - from.DayNumber + 1));
        for (var d = from; d <= to; d = d.AddDays(1))
        {
            if (_days.TryGetValue(d, out var day))
                result.Add(day);
        }
        return result;
    }
}
