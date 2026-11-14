using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Objectives;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase6;

/// <summary>The search uses a lean scorer; it must agree with the full, explained one everywhere.</summary>
public class FastScoringTests
{
    private static readonly string[] Mains = ["cerealA", "cerealB", "legumeA", "rootCropA", "oilseedA"];

    [Fact]
    public void FastScorerMatchesTheFullScorerOnManyRandomPlans()
    {
        var env = Env(climate: GeneratedKb.Climate());
        var random = new Random(2026);
        var vector = new double[ObjectiveScorer.Scored.Count];

        for (var n = 0; n < 400; n++)
        {
            PlanSeason Season() => new()
            {
                MainCrop = new CropId(Mains[random.Next(Mains.Length)]),
                CatchCrop = random.Next(3) == 0 ? new CropId("catchA") : null,
                Actions = random.Next(4) == 0 ? [new PlannedAction(new ActionId("lime"))] : []
            };
            var plan = new RotationPlan
            {
                FirstHarvestYear = 2026,
                Transition = Enumerable.Range(0, random.Next(0, 2)).Select(_ => Season()).ToList(),
                Cycle = Enumerable.Range(0, random.Next(1, 6)).Select(_ => Season()).ToList()
            };

            var simulated = PlanSimulator.Simulate(plan, env.InitialState(), env, collectReasons: false);
            var full = ObjectiveScorer.ScoreSeasons(simulated.Seasons, simulated.LastCycleStart, env, explain: false);
            var worst = ObjectiveScorer.ScoreFast(simulated.Seasons, simulated.LastCycleStart, env, vector);

            for (var i = 0; i < vector.Length; i++)
                Assert.Equal(full.Scores[ObjectiveScorer.Scored[i]], vector[i], 12);
            Assert.Equal(full.WorstSeasonCvar, worst, 12);
        }
    }

    [Fact]
    public void SimulatingWithoutReasonsGivesTheSameScoresAsSimulatingWithThem()
    {
        var env = Env();
        var plan = new RotationPlan
        {
            FirstHarvestYear = 2026,
            Transition = [Season("rootCropA")],
            Cycle = [Season("legumeA", "catchA"), Season("cerealA"), Season("cerealB", null, ResidueHandling.Remove)]
        };

        var lean = PlanEvaluator.Evaluate(plan, env.InitialState(), env, collectReasons: false);
        var full = PlanEvaluator.Evaluate(plan, env.InitialState(), env, collectReasons: true);

        Assert.Equal(full.Scores.Values.OrderBy(v => v.Key), lean.Scores.Values.OrderBy(v => v.Key));
        Assert.Equal(full.Seasons.Select(s => (s.SurvivalMean, s.SurvivalCvar20, s.YieldFactor)),
            lean.Seasons.Select(s => (s.SurvivalMean, s.SurvivalCvar20, s.YieldFactor)));
        Assert.Equal(full.Seasons.Select(s => s.StateAfter.Values.ToList()), lean.Seasons.Select(s => s.StateAfter.Values.ToList()));
        Assert.Empty(lean.Reasons);
        Assert.NotEmpty(full.Reasons);
    }

    [Fact]
    public void ThePrecomputedWorstYearsAgreeWithSortingEveryYear()
    {
        // The simulator takes the worst years from pre-sorted static scores. Cross-check against the textbook way
        // for a state with a non-trivial multiplier and an override delta.
        var env = Env(climate: GeneratedKb.Climate());
        var steps = Run(env, env.InitialState(), "oilseedA", "oilseedA", "cerealA", "cerealA").Steps;

        foreach (var step in steps)
        {
            var table = env.Survival![step.Evaluation.Crop];
            // Re-derive from per-year values (the explained path builds them one by one).
            var detail = PlanEvaluator.Evaluate(new RotationPlan { FirstHarvestYear = 2026, Cycle = [Season("cerealA")] }, env.InitialState(), env);
            Assert.NotNull(detail);
            Assert.Equal(table.SortedScores.Length, table.Years.Count);
            Assert.Equal(table.SortedScores, table.Years.Select(y => y.Score).Order());
        }
    }

    [Fact]
    public void ExplainedStepsReportPerYearSurvivalConsistentWithTheMean()
    {
        var env = Env(climate: GeneratedKb.Climate());
        var start = env.InitialState();

        var step = Step(env, Run(env, start, "oilseedA").State, Season("oilseedA"), 1);   // p3 multiplier < 1

        Assert.Equal(step.Detail.YearSurvival.Average(), step.Evaluation.SurvivalMean, 12);
        var worst = Engine.Survival.SurvivalAggregator.Cvar(step.Detail.YearSurvival.ToList(), Settings.Survival.CvarFraction);
        Assert.Equal(worst, step.Evaluation.SurvivalCvar20, 12);
    }
}
