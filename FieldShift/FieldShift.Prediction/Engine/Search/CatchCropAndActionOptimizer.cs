using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Engine.Validation;

namespace FieldShift.Prediction.Engine.Search;

/// <summary>Where a catch crop fits between two main crops.</summary>
public static class CatchCropFeasibility
{
    /// <summary>
    /// A catch crop can follow <paramref name="previous"/> when the next main crop is a spring crop and
    /// <c>previous harvest + soil preparation + minimum growth days</c> fits before
    /// <c>min(latest end day, last sowing day of the catch crop + its growing period)</c>.
    /// </summary>
    public static bool IsFeasible(Crop previous, Crop catchCrop, Crop next, EngineSettings settings)
    {
        if (catchCrop.Type != CropType.Catch || next.Type != CropType.Spring)
            return false;

        var calendar = settings.Calendar;
        var needed = previous.HarvestWindow.End + calendar.SoilPrepDays + calendar.CatchCropMinGrowthDays;
        var limit = Math.Min(calendar.CatchCropLatestEndDoy, catchCrop.SowWindow.End + GrowingPeriodDays(catchCrop));
        return needed <= limit;
    }

    /// <summary>Sum of the stage lengths; without them, the days from the last sowing day to the last harvest day.</summary>
    public static int GrowingPeriodDays(Crop crop) =>
        crop.Water is { StageLengthsDays.Count: 4 } w
            ? w.StageLengthsDays.Sum()
            : Math.Max(0, crop.HarvestWindow.End - crop.SowWindow.End);
}

public sealed record OptimizedPlan(RotationPlan Plan, double Score, int AcceptedChanges);

/// <summary>
/// Second pass for the best plans only: adds catch crops between seasons and management actions, by hill climbing.
/// In each pass, for each season, the single best improving change is applied; then the whole plan is simulated
/// again. A change is accepted only if it raises the strategy's weighted score and keeps every season's survival
/// above the strategy's floor.
/// </summary>
public sealed class CatchCropAndActionOptimizer
{
    private const double MinimumGain = 1e-9;

    private readonly SimEnvironment _env;
    private readonly SimState _start;
    private readonly Strategy _strategy;
    private readonly IReadOnlyList<Crop> _catchCrops;
    private readonly IReadOnlyList<ManagementActionDefinition> _actions;
    private readonly double[] _weights;

    public CatchCropAndActionOptimizer(
        SimEnvironment env, SimState start, Strategy strategy, IEnumerable<Crop> catchCrops)
    {
        _env = env;
        _start = start;
        _strategy = strategy;
        _catchCrops = catchCrops.Where(c => c.Type == CropType.Catch).OrderBy(c => c.Id.Value, StringComparer.Ordinal).ToList();
        _weights = StrategySelector.Weights(strategy, Objectives.ObjectiveScorer.Scored);

        // Actions the farmer can actually do. Their own requirement is checked against the farmer inputs here;
        // the simulator checks it again (with the season's residue handling) when applying.
        _actions = env.Kb.Actions.Values
            .Where(a => a.RequiresFarmerInput is null || ConditionEvaluator.IsSupported(a.RequiresFarmerInput))
            .Where(a => a.RequiresFarmerInput is null || FarmerHolds(a.RequiresFarmerInput))
            .OrderBy(a => a.Id.Value, StringComparer.Ordinal)
            .ToList();
    }

    private bool FarmerHolds(string requirement) =>
        // Residue handling is a per-season choice, so a residue condition counts as possible here.
        requirement.StartsWith(ConditionEvaluator.ResidueNamespace, StringComparison.Ordinal)
        || ConditionEvaluator.Evaluate(requirement, ResidueHandling.Incorporate, _env.Farmer);

    public OptimizedPlan Optimize(RotationPlan plan)
    {
        var current = plan;
        var (score, feasible) = Evaluate(current);
        var accepted = 0;

        for (var pass = 0; pass < _env.Settings.Search.LocalSearchPasses; pass++)
        {
            var improvedInPass = false;

            for (var position = 0; position < plan.Transition.Count + plan.CycleLength; position++)
            {
                RotationPlan? best = null;
                var bestScore = score;

                foreach (var option in Options(current, position))
                {
                    var (optionScore, ok) = Evaluate(option);
                    if (ok && optionScore > bestScore + MinimumGain)
                        (best, bestScore) = (option, optionScore);
                }

                if (best is not null)
                {
                    current = best;
                    score = bestScore;
                    accepted++;
                    improvedInPass = true;
                }
            }

            if (!improvedInPass) break;
        }

        return new OptimizedPlan(current, score, accepted);
    }

    private (double Score, bool Feasible) Evaluate(RotationPlan plan)
    {
        var evaluation = PlanEvaluator.Evaluate(plan, _start, _env, collectReasons: false);
        var vector = Objectives.ObjectiveScorer.Scored.Select(o => evaluation.Scores[o]).ToArray();
        var floorOk = evaluation.Seasons.All(s => s.SurvivalCvar20 >= _strategy.SurvivalFloor - 1e-9);
        return (StrategySelector.WeightedScore(_weights, vector), floorOk);
    }

    /// <summary>All single changes at one position: another catch crop (or none), and adding or removing an action.</summary>
    private IEnumerable<RotationPlan> Options(RotationPlan plan, int position)
    {
        var season = SeasonAt(plan, position);
        var main = _env.Kb.GetCrop(season.MainCrop);
        var next = _env.Kb.GetCrop(NextMainCrop(plan, position));

        if (season.CatchCrop is not null)
            yield return Replace(plan, position, season with { CatchCrop = null });

        foreach (var c in _catchCrops)
        {
            if (season.CatchCrop == c.Id) continue;
            if (CatchCropFeasibility.IsFeasible(main, c, next, _env.Settings))
                yield return Replace(plan, position, season with { CatchCrop = c.Id });
        }

        foreach (var a in _actions)
        {
            var present = season.Actions.Any(x => x.Action == a.Id);
            var actions = present
                ? season.Actions.Where(x => x.Action != a.Id).ToList()
                : [.. season.Actions, new PlannedAction(a.Id)];
            yield return Replace(plan, position, season with { Actions = actions });
        }
    }

    private static PlanSeason SeasonAt(RotationPlan plan, int position) =>
        position < plan.Transition.Count ? plan.Transition[position] : plan.Cycle[position - plan.Transition.Count];

    /// <summary>The main crop that follows; the last season of the cycle is followed by the first (wrap-around).</summary>
    private static CropId NextMainCrop(RotationPlan plan, int position)
    {
        var next = position + 1;
        return next < plan.Transition.Count ? plan.Transition[next].MainCrop
            : next - plan.Transition.Count < plan.CycleLength ? plan.Cycle[next - plan.Transition.Count].MainCrop
            : plan.Cycle[0].MainCrop;
    }

    private static RotationPlan Replace(RotationPlan plan, int position, PlanSeason season)
    {
        if (position < plan.Transition.Count)
        {
            var t = plan.Transition.ToList();
            t[position] = season;
            return plan with { Transition = t };
        }

        var c = plan.Cycle.ToList();
        c[position - plan.Transition.Count] = season;
        return plan with { Cycle = c };
    }
}
