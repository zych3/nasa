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

    /// <summary>Weight of a year: 0.5 for every <paramref name="halfLifeYears"/> before the latest year.</summary>
    public static double RecencyWeight(int year, int latestYear, double halfLifeYears) =>
        Math.Pow(0.5, (latestYear - year) / halfLifeYears);

    public static double WeightedMean(IReadOnlyList<double> values, IReadOnlyList<double> weights)
    {
        if (values.Count == 0) return 0.0;
        double sum = 0, total = 0;
        for (var i = 0; i < values.Count; i++)
        {
            sum += weights[i] * values[i];
            total += weights[i];
        }
        return sum / total;
    }

    /// <summary>The weight mass that forms the worst tail: the same share of years as <see cref="Cvar"/> uses.</summary>
    public static double TailMass(int count, double fraction, double totalWeight) =>
        WorstCount(count, fraction) / (double)count * totalWeight;

    /// <summary>
    /// Mean of the worst tail, where the tail holds <see cref="TailMass"/> of the total weight, taken from the lowest
    /// value upwards (the last year only partly). With equal weights this is exactly <see cref="Cvar"/>.
    /// </summary>
    public static double WeightedCvar(IReadOnlyList<double> values, IReadOnlyList<double> weights, double fraction)
    {
        if (values.Count == 0) return 0.0;

        var order = Enumerable.Range(0, values.Count).OrderBy(i => values[i]).ThenBy(i => i).ToArray();
        var target = TailMass(values.Count, fraction, weights.Sum());
        double taken = 0, sum = 0;
        foreach (var i in order)
        {
            var take = Math.Min(weights[i], target - taken);
            if (take <= 1e-12) break;
            sum += take * values[i];
            taken += take;
        }
        return sum / taken;
    }
}
