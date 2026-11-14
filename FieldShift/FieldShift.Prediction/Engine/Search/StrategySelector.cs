using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Search;

public static class StrategySelector
{
    private const double Epsilon = 1e-9;

    public static double[] Weights(Strategy strategy, IReadOnlyList<Objective> axes)
    {
        var w = axes.Select(a => strategy.Weights.TryGetValue(a, out var x) ? x : 0.0).ToArray();
        var sum = w.Sum();
        if (sum <= 0)
            throw new InvalidOperationException(Fmt.Inv($"Strategy '{strategy.Id}' has no weight on any scored objective."));
        return w.Select(x => x / sum).ToArray();
    }

    public static double WeightedScore(double[] weights, double[] vector)
    {
        double sum = 0;
        for (var i = 0; i < weights.Length; i++) sum += weights[i] * vector[i];
        return sum;
    }

    public static bool IsEligible(Strategy strategy, PlanCandidate c) =>
        IsEligible(strategy, c.CycleLength, c.WorstSeasonCvar);

    public static bool IsEligible(Strategy strategy, int cycleLength, double worstSeasonCvar) =>
        cycleLength >= strategy.MinCycleYears && cycleLength <= strategy.MaxCycleYears
        && worstSeasonCvar >= strategy.SurvivalFloor - Epsilon;

    /// <summary>
    /// Eligible plans, best first.
    /// WeightedSum ranks the Pareto front plus the strategy's top-K list by weighted score.
    /// Knee ranks the eligible front members by weighted distance to the ideal point (1, ..., 1) after min-max
    /// normalisation across them; if none of the front is eligible it falls back to the top-K list.
    /// Ties go to the smaller plan key, so the order never depends on how the search was scheduled.
    /// </summary>
    public static IReadOnlyList<PlanCandidate> Rank(
        Strategy strategy, IReadOnlyList<PlanCandidate> front, IReadOnlyList<PlanCandidate> topK,
        IReadOnlyList<Objective> axes)
    {
        var weights = Weights(strategy, axes);
        var eligibleFront = front.Where(c => IsEligible(strategy, c)).ToList();
        var eligibleTop = topK.Where(c => IsEligible(strategy, c)).ToList();

        if (strategy.Mode == SelectionMode.WeightedSum)
        {
            return eligibleFront.Concat(eligibleTop)
                .DistinctBy(c => c.Key)
                .OrderByDescending(c => WeightedScore(weights, c.Vector))
                .ThenBy(c => c.Key, StringComparer.Ordinal)
                .ToList();
        }

        var pool = eligibleFront.Count > 0 ? eligibleFront : eligibleTop;
        if (pool.Count == 0) return [];

        var min = new double[axes.Count];
        var max = new double[axes.Count];
        for (var i = 0; i < axes.Count; i++)
        {
            min[i] = pool.Min(c => c.Vector[i]);
            max[i] = pool.Max(c => c.Vector[i]);
        }

        double Distance(PlanCandidate c)
        {
            double sum = 0;
            for (var i = 0; i < axes.Count; i++)
            {
                var range = max[i] - min[i];
                var normalised = range <= 0 ? 1.0 : (c.Vector[i] - min[i]) / range;
                sum += weights[i] * (1 - normalised) * (1 - normalised);
            }
            return Math.Sqrt(sum);
        }

        return pool.DistinctBy(c => c.Key)
            .OrderBy(Distance)
            .ThenBy(c => c.Key, StringComparer.Ordinal)
            .ToList();
    }

    public static IReadOnlyList<PlanCandidate> PickBestAndAlternatives(
        IReadOnlyList<PlanCandidate> ranked, SearchSettings search)
    {
        var chosen = new List<PlanCandidate>();
        foreach (var c in ranked)
        {
            if (chosen.Count == 0)
            {
                chosen.Add(c);
                continue;
            }
            if (chosen.Count > search.AlternativesPerStrategy) break;
            if (chosen.All(x => JaccardDistance(x, c) >= search.MinAlternativeJaccardDistance - Epsilon))
                chosen.Add(c);
        }
        return chosen;
    }

    public static double JaccardDistance(PlanCandidate a, PlanCandidate b)
    {
        var shared = a.Crops.Intersect(b.Crops).Count();
        var union = a.Crops.Union(b.Crops).Count();
        return union == 0 ? 0.0 : 1.0 - (double)shared / union;
    }
}
