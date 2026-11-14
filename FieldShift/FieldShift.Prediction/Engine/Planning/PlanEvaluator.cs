using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Objectives;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Planning;

public static class PlanEvaluator
{
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
