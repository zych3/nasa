namespace FieldShift.Prediction.Engine.Survival;

/// <summary>Combines survival factors and summarises survival over climate years.</summary>
public static class SurvivalAggregator
{
    /// <summary>Combines factors in [0, 1] with the configured aggregator. No factors means nothing limits survival: 1.</summary>
    public static double Combine(IEnumerable<double> factors, FactorAggregation aggregation)
    {
        var list = factors.ToList();
        if (list.Count == 0) return 1.0;

        return aggregation switch
        {
            FactorAggregation.Min => list.Min(),
            FactorAggregation.GeometricMean => list.Any(f => f <= 0)
                ? 0.0
                : Math.Exp(list.Average(Math.Log)),
            _ => throw new NotSupportedException(Fmt.Inv($"Unknown aggregation '{aggregation}'."))
        };
    }

    public static double Mean(IReadOnlyCollection<double> values) => values.Count == 0 ? 0.0 : values.Average();

    /// <summary>How many of <paramref name="n"/> values count as "the worst fraction": ⌈fraction · n⌉, at least 1.</summary>
    public static int WorstCount(int n, double fraction) => Math.Clamp((int)Math.Ceiling(fraction * n - 1e-9), 1, n);

    /// <summary>Mean of the worst ⌈fraction · n⌉ values (conditional value at risk).</summary>
    public static double Cvar(IReadOnlyCollection<double> values, double fraction)
    {
        if (values.Count == 0) return 0.0;
        var k = WorstCount(values.Count, fraction);
        return values.Order().Take(k).Average();
    }
}
