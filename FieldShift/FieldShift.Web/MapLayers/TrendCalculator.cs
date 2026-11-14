namespace FieldShift.Web.MapLayers;

public enum YearlyAggregation
{
    Mean,
    Sum,
}

/// <summary>Anomalies, summary statistics and linear trends of monthly series. Pure logic.</summary>
public static class TrendCalculator
{
    /// <summary>Value minus the mean of the same calendar month over the whole series; null where the value is null.</summary>
    public static double?[] Anomalies(IReadOnlyList<double?> values, IReadOnlyList<YearMonth> months)
    {
        var monthlyMeans = new double?[13];
        for (var m = 1; m <= 12; m++)
        {
            var sameMonth = Enumerable.Range(0, values.Count)
                .Where(i => months[i].Month == m && values[i].HasValue)
                .Select(i => values[i]!.Value)
                .ToList();
            monthlyMeans[m] = sameMonth.Count > 0 ? sameMonth.Average() : null;
        }

        return Enumerable.Range(0, values.Count)
            .Select(i => values[i] is { } v && monthlyMeans[months[i].Month] is { } mean ? v - mean : (double?)null)
            .ToArray();
    }

    /// <summary>
    /// Slope of a least-squares line through yearly values × 10 (unit per decade). A year counts only when all
    /// 12 months are in the series and none is null. Null with fewer than 2 complete years.
    /// </summary>
    public static double? TrendPerDecade(
        IReadOnlyList<double?> values,
        IReadOnlyList<YearMonth> months,
        YearlyAggregation aggregation)
    {
        var yearly = Enumerable.Range(0, values.Count)
            .GroupBy(i => months[i].Year)
            .Where(g => g.Count() == 12 && g.All(i => values[i].HasValue))
            .Select(g =>
            {
                var monthValues = g.Select(i => values[i]!.Value).ToList();
                var y = aggregation == YearlyAggregation.Mean ? monthValues.Average() : monthValues.Sum();
                return (X: (double)g.Key, Y: y);
            })
            .ToList();

        return LinearSlope(yearly) * 10;
    }

    /// <summary>Least-squares slope dy/dx; null with fewer than 2 points or no spread in x.</summary>
    public static double? LinearSlope(IReadOnlyList<(double X, double Y)> points)
    {
        if (points.Count < 2)
        {
            return null;
        }

        var meanX = points.Average(p => p.X);
        var meanY = points.Average(p => p.Y);
        var sxx = points.Sum(p => (p.X - meanX) * (p.X - meanX));
        if (sxx == 0)
        {
            return null;
        }

        var sxy = points.Sum(p => (p.X - meanX) * (p.Y - meanY));
        return sxy / sxx;
    }

    public static (double? Min, double? Max, double? Mean) Stats(IEnumerable<double?> values)
    {
        var present = values.OfType<double>().ToList();
        return present.Count > 0 ? (present.Min(), present.Max(), present.Average()) : (null, null, null);
    }
}
