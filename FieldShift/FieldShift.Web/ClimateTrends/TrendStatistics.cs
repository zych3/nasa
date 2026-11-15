namespace FieldShift.Web.ClimateTrends;

/// <summary>Result of a trend test on one yearly series.</summary>
/// <param name="SlopePerYear">Sen slope: the median change per year over all pairs of years.</param>
/// <param name="PValue">Two-sided p-value of the Mann–Kendall test (small = the trend is unlikely to be chance).</param>
public readonly record struct TrendResult(double SlopePerYear, double PValue);

/// <summary>
/// Mann–Kendall trend test with the Sen slope: the usual pair for climate series, because neither assumes normal
/// values (counts of hot days are not) and one odd year does not move the result. Pure logic.
/// </summary>
public static class TrendStatistics
{
    /// <summary>Trend of <paramref name="values"/> over <paramref name="years"/>; null with fewer than 3 points.</summary>
    public static TrendResult? Analyze(IReadOnlyList<int> years, IReadOnlyList<double> values)
    {
        var n = values.Count;
        if (n < 3 || years.Count != n)
            return null;

        var s = 0;
        var slopes = new List<double>(n * (n - 1) / 2);
        for (var i = 0; i < n - 1; i++)
        {
            for (var j = i + 1; j < n; j++)
            {
                s += Math.Sign(values[j] - values[i]);
                if (years[j] != years[i])
                    slopes.Add((values[j] - values[i]) / (years[j] - years[i]));
            }
        }

        // Equal values (ties) carry no information about direction, so they shrink the variance of S.
        var ties = values.GroupBy(v => v).Select(g => g.Count()).Where(t => t > 1)
            .Sum(t => (double)t * (t - 1) * (2 * t + 5));
        var variance = (n * (n - 1) * (2.0 * n + 5) - ties) / 18.0;

        var z = variance <= 0 || s == 0 ? 0 : (s - Math.Sign(s)) / Math.Sqrt(variance);
        var p = z == 0 ? 1 : Math.Clamp(2 * (1 - NormalCdf(Math.Abs(z))), 0, 1);

        return new TrendResult(Median(slopes), p);
    }

    public static double Median(List<double> values)
    {
        if (values.Count == 0)
            return 0;
        values.Sort();
        var mid = values.Count / 2;
        return values.Count % 2 == 1 ? values[mid] : (values[mid - 1] + values[mid]) / 2;
    }

    /// <summary>Standard normal distribution function (Abramowitz–Stegun 7.1.26, error below 1.5e-7).</summary>
    public static double NormalCdf(double z)
    {
        var x = Math.Abs(z) / Math.Sqrt(2);
        var t = 1 / (1 + 0.3275911 * x);
        var poly = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
        var erf = 1 - poly * Math.Exp(-x * x);
        return z >= 0 ? 0.5 * (1 + erf) : 0.5 * (1 - erf);
    }
}
