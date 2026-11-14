namespace FieldShift.Prediction.Engine.Survival;

public static class SurvivalAggregator
{
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

    public static int WorstCount(int n, double fraction) => Math.Clamp((int)Math.Ceiling(fraction * n - 1e-9), 1, n);

    public static double Cvar(IReadOnlyCollection<double> values, double fraction)
    {
        if (values.Count == 0) return 0.0;
        var k = WorstCount(values.Count, fraction);
        return values.Order().Take(k).Average();
    }
}
