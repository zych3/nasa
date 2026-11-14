using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Objectives;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Planning;

/// <summary>Simulates a plan and scores it: the single entry point from a plan to a <see cref="PlanEvaluation"/>.</summary>
public static class PlanEvaluator
{
    /// <param name="collectReasons">
    /// False gives the same scores and states without reasons, much faster. Used for the Pareto front and the search.
    /// </param>
    public static PlanEvaluation Evaluate(RotationPlan plan, SimState start, SimEnvironment env, bool collectReasons = true)
    {
        var simulated = PlanSimulator.Simulate(plan, start, env, collectReasons);
        var objectives = ObjectiveScorer.ScoreSeasons(simulated.Seasons, simulated.LastCycleStart, env, collectReasons);

        return new PlanEvaluation
        {
            Plan = plan,
            Seasons = simulated.Seasons.Select(s => s.Step.Evaluation).ToList(),
            Scores = objectives.Scores,
            Reasons = collectReasons
                ? simulated.Seasons.SelectMany(s => s.Step.Reasons).Concat(objectives.Reasons).ToList()
                : []
        };
    }
}
