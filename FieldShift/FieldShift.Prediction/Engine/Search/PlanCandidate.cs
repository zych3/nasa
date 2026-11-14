using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Objectives;

namespace FieldShift.Prediction.Engine.Search;

/// <summary>A scored plan kept by the search. Light: no per-season states or reasons.</summary>
public sealed class PlanCandidate
{
    private ObjectiveScores? _scores;
    private IReadOnlyList<string>? _crops;

    public required RotationPlan Plan { get; init; }

    /// <summary>Scores in <see cref="ObjectiveScorer.Scored"/> order, for fast dominance checks.</summary>
    public required double[] Vector { get; init; }

    /// <summary>The same scores by objective. Built on first use: the search itself only needs <see cref="Vector"/>.</summary>
    public ObjectiveScores Scores
    {
        get => _scores ??= new ObjectiveScores(
            ObjectiveScorer.Scored.Select((o, i) => (o, v: Vector[i])).ToDictionary(x => x.o, x => x.v));
        init => _scores = value;
    }

    /// <summary>Lowest survival CVaR over every simulated season, transition and wrap-around included.</summary>
    public required double WorstSeasonCvar { get; init; }

    /// <summary>Stable text identity, e.g. "oilseedA/cerealA|legumeA|cerealB". Orders ties deterministically.</summary>
    public required string Key { get; init; }

    /// <summary>Distinct main crops of transition and cycle, sorted. For the alternative-plan distance. Built on first use.</summary>
    public IReadOnlyList<string> Crops
    {
        get => _crops ??= Plan.Transition.Concat(Plan.Cycle).Select(s => s.MainCrop.Value)
            .Distinct().Order(StringComparer.Ordinal).ToList();
        init => _crops = value;
    }

    public int CycleLength => Plan.CycleLength;

    public static string BuildKey(RotationPlan plan) =>
        string.Join('|', plan.Transition.Select(s => s.MainCrop.Value)) + "/" +
        string.Join('|', plan.Cycle.Select(s => s.MainCrop.Value));

    public static PlanCandidate From(RotationPlan plan, ObjectiveResult scored) => new()
    {
        Plan = plan,
        Scores = scored.Scores,
        Vector = ObjectiveScorer.Scored.Select(o => scored.Scores[o]).ToArray(),
        WorstSeasonCvar = scored.WorstSeasonCvar,
        Key = BuildKey(plan)
    };

    public static PlanCandidate FromVector(RotationPlan plan, double[] vector, double worstSeasonCvar) => new()
    {
        Plan = plan,
        Vector = vector,
        WorstSeasonCvar = worstSeasonCvar,
        Key = BuildKey(plan)
    };
}

public sealed record SearchStats(
    long Nodes, long Leaves, long Scored, long PrunedByConstraint, long PrunedBySurvival,
    long PrunedByBound, long Duplicates)
{
    public static SearchStats operator +(SearchStats a, SearchStats b) => new(
        a.Nodes + b.Nodes, a.Leaves + b.Leaves, a.Scored + b.Scored, a.PrunedByConstraint + b.PrunedByConstraint,
        a.PrunedBySurvival + b.PrunedBySurvival, a.PrunedByBound + b.PrunedByBound, a.Duplicates + b.Duplicates);

    public static SearchStats Zero { get; } = new(0, 0, 0, 0, 0, 0, 0);
}
