namespace FieldShift.Prediction.Domain;

public sealed record PlannedAction(ActionId Action, double? Amount = null);
 
public sealed record PlanSeason
{
    public required CropId MainCrop { get; init; }
    public CropId? CatchCrop { get; init; }
    public ResidueHandling? Residue { get; init; }
    public IReadOnlyList<PlannedAction> Actions { get; init; } = [];
}

public sealed record RotationPlan
{
    public required int FirstHarvestYear { get; init; }
    public IReadOnlyList<PlanSeason> Transition { get; init; } = [];
    public required IReadOnlyList<PlanSeason> Cycle { get; init; }
 
    public int CycleLength => Cycle.Count;
 
    public IEnumerable<(int HarvestYear, PlanSeason Season, bool IsTransition)> Unroll(int cycles = 2)
    {
        var year = FirstHarvestYear;
        foreach (var s in Transition)
            yield return (year++, s, true);
 
        for (var c = 0; c < cycles; c++)
            foreach (var s in Cycle)
                yield return (year++, s, false);
    }
}
 
public sealed record SeasonEvaluation
{
    public required int SeasonIndex { get; init; }
    public required int HarvestYear { get; init; }
    public required CropId Crop { get; init; }
 
    public required double SurvivalMean { get; init; }
 
    public required double SurvivalCvar20 { get; init; }
 
    public required double YieldFactor { get; init; }
    public required SoilState StateBefore { get; init; }
    public required SoilState StateAfter { get; init; }
}
 
public sealed record ObjectiveScores(IReadOnlyDictionary<Objective, double> Values)
{
    public double this[Objective objective] => Values.TryGetValue(objective, out var v) ? v : 0;
 
    public bool Dominates(ObjectiveScores other)
    {
        var strictlyBetter = false;
        foreach (var o in Enum.GetValues<Objective>())
        {
            if (this[o] < other[o]) return false;
            if (this[o] > other[o]) strictlyBetter = true;
        }
        return strictlyBetter;
    }
}
 
public sealed record PlanEvaluation
{
    public required RotationPlan Plan { get; init; }
    public required IReadOnlyList<SeasonEvaluation> Seasons { get; init; }
    public required ObjectiveScores Scores { get; init; }
    public IReadOnlyList<Reason> Reasons { get; init; } = [];
    public IReadOnlyList<Reason> Violations { get; init; } = [];
    public bool IsFeasible => Violations.Count == 0;
}
 
public sealed record Recommendation
{
    public required StrategyId Strategy { get; init; }
    public required PlanEvaluation Best { get; init; }
    public IReadOnlyList<PlanEvaluation> Alternatives { get; init; } = [];
    public required double StrategyScore { get; init; }
    public required string KnowledgeBaseVersion { get; init; }
    public required DateTimeOffset GeneratedAtUtc { get; init; }
}