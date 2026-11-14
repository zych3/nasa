using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Objectives;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase5;

public class ObjectiveScorerTests
{
    private static RotationPlan Plan(string[] cycle, string[]? transition = null) => new()
    {
        FirstHarvestYear = 2030,
        Transition = (transition ?? []).Select(c => Season(c)).ToList(),
        Cycle = cycle.Select(c => Season(c)).ToList()
    };

    private static ObjectiveResult Score(SimEnvironment env, string[] cycle, string[]? transition = null)
    {
        var simulated = PlanSimulator.Simulate(Plan(cycle, transition), env.InitialState(), env);
        return ObjectiveScorer.Score(simulated, env);
    }

    private static ObjectiveResult Score(params string[] cycle) => Score(Env(), cycle);

    private static double S(ObjectiveResult r, Objective o) => r.Scores[o];

    // Monoculture of cerealB, steady state (the second cycle repetition):
    //   before the last season: p1 = 0.2 (0.2 load from season 0), residualN = 0, compaction = 0, no cover.
    //   yield = p1 curve (0 -> 1, 1 -> 0.8) at 0.2 = 0.96, minus the 0.1 cereal-after-cereal override = 0.86.
    //   static survival of cerealB on the sandy fixture plot = texture min(0.8333, 0.8571) = 0.8333.

    private const double StaticCerealB = 12.5 / 15.0;

    [Fact]
    public void SurvivalIsCvarTimesYieldFactor() =>
        Assert.Equal(StaticCerealB * 0.86, S(Score("cerealB"), Objective.Survival), 9);

    [Fact]
    public void HumusUsesTheMeanAnnualChangeOverTheCycle()
    {
        var r = Score("cerealB");

        Assert.Equal(40, r.Raw[Objective.Humus], 9);
        Assert.Equal(0.6 + 0.4 * (40.0 / 200.0), S(r, Objective.Humus), 9);
    }

    [Fact]
    public void HumusChangeIsAveragedPerYearForALongerCycle()
    {
        var r = Score("cerealA", "legumeA");

        Assert.Equal(65, r.Raw[Objective.Humus], 9);
    }

    [Fact]
    public void PathogenMapsTheMeanPressureOnRespondedVariables()
    {
        var r = Score("cerealB");

        Assert.Equal(0.2, r.Raw[Objective.Pathogen], 9);
        Assert.Equal(1 - 0.6 * (0.2 / 0.5), S(r, Objective.Pathogen), 9);
    }

    [Fact]
    public void PathogenWeighsResponsesByTheirWeight()
    {
        // p1 weight 3 and p2 weight 1 with p1 = 0.2, p2 = 0: pressure (3 * 0.2 + 0) / 4 = 0.15
        var kb = WithCrop(Kb, "cerealB", c => c with
        {
            Responses =
            [
                new Response { Var = new StateVarId("pathogen:p1"), Curve = Curve.Constant(1), Target = ResponseTarget.Yield, Weight = 3 },
                new Response { Var = new StateVarId("pathogen:p2"), Curve = Curve.Constant(1), Target = ResponseTarget.Yield, Weight = 1 }
            ]
        });

        var r = Score(Env(kb), ["cerealB"]);

        Assert.Equal(0.15, r.Raw[Objective.Pathogen], 9);
    }

    [Fact]
    public void PathogenIgnoresNonPressureResponsesAndSeasonsWithNone()
    {
        var kb = WithCrop(Kb, "cerealB", c => c with { Responses = c.Responses.Where(x => x.Var == StateVarId.Ph).ToList() });

        var r = Score(Env(kb), ["cerealB"]);

        Assert.Equal(0, r.Raw[Objective.Pathogen]);
        Assert.Equal(1, S(r, Objective.Pathogen));
    }

    [Fact]
    public void NitrogenIsTheShareOfTheNeedCoveredByPredecessors()
    {
        var r = Score("legumeA", "cerealA");

        Assert.Equal((1.0 + 40.0 / 150.0) / 2, S(r, Objective.Nitrogen), 9);
    }

    [Fact]
    public void NitrogenIsCappedAtOne()
    {
        var kb = WithCrop(Kb, "cerealB", c => c with { Management = c.Management with { NRateKgHa = 5 } });
        var kb2 = WithCrop(kb, "legumeA", c => c with { Effects = [.. c.Effects, Eff("residualN", EffectOp.Add, 100)] });

        var r = Score(Env(kb2), ["legumeA", "cerealB"]);

        Assert.Equal(1.0, S(r, Objective.Nitrogen), 9);
    }

    [Fact]
    public void CoverAveragesTheWinterCoverAfterEachSeason()
    {
        Assert.Equal(0.4, S(Score("cerealA", "legumeA"), Objective.Cover), 9);
    }

    [Fact]
    public void StructureAveragesCompactionWithRootDepthDiversity()
    {
        // cerealB: compaction stays 0 -> 0.7; root depth 1.0 m -> class 2 -> one class / 3
        var r = Score("cerealB");

        Assert.Equal((0.7 + 1.0 / 3.0) / 2, S(r, Objective.Structure), 9);
        Assert.Equal(0, r.Raw[Objective.Structure], 9);
    }

    [Fact]
    public void StructureUsesTheFinalCompactionOfTheUnrolledPlan()
    {
        // rootCropA adds 0.2 per season: 0.4 after two cycles -> curve (0, 0.7) -> (0.5, 0): 0.7 - 0.7 * 0.4/0.5 = 0.14.
        // Depths: rootCropA 0.8 m (class 1), cerealB 1.0 m (class 2) -> 2 classes / 3.
        var r = Score("rootCropA", "cerealB");

        Assert.Equal(0.4, r.Raw[Objective.Structure], 9);
        Assert.Equal((0.14 + 2.0 / 3.0) / 2, S(r, Objective.Structure), 9);
    }

    [Fact]
    public void RootDepthDiversityIsCappedAtOne()
    {
        var kb = WithCrop(Kb, "catchA", c => c with { Water = c.Water! with { RootDepthM = 0.3 } });
        var env = Env(kb);
        var plan = new RotationPlan
        {
            FirstHarvestYear = 2030,
            Cycle = [Season("cerealA"), Season("legumeA", "catchA")]
        };

        var scored = ObjectiveScorer.Score(PlanSimulator.Simulate(plan, env.InitialState(), env), env);

        // compaction is 0 throughout -> 0.7; diversity min(1, 3 / 3) = 1
        Assert.Equal((0.7 + 1.0) / 2, S(scored, Objective.Structure), 9);
    }

    [Fact]
    public void CatchCropsCountTowardsRootDepthClasses()
    {
        var env = Env();
        var without = new RotationPlan { FirstHarvestYear = 2030, Cycle = [Season("cerealB")] };
        var with = new RotationPlan { FirstHarvestYear = 2030, Cycle = [Season("cerealB", "catchA")] };

        var a = ObjectiveScorer.Score(PlanSimulator.Simulate(without, env.InitialState(), env), env);
        var b = ObjectiveScorer.Score(PlanSimulator.Simulate(with, env.InitialState(), env), env);

        Assert.Equal((0.7 + 1.0 / 3.0) / 2, S(a, Objective.Structure), 9);
        Assert.Equal((0.7 + 2.0 / 3.0) / 2, S(b, Objective.Structure), 9);
    }

    [Fact]
    public void WaterIsOneMinusTheMeanStress()
    {
        var dry = Weather.Years(2000, 25, y => Weather.Constant(y, 5, 15, 0, 5, 0));
        var env = Env(climate: dry);
        var stress = new[] { "cerealB", "legumeA" }
            .Select(c => env.Survival![new CropId(c)].Years.Average(y => y.Factors.WaterStress)).Average();

        var r = Score(env, ["cerealB", "legumeA"]);

        Assert.True(stress > 0.1, "the drought climate should produce stress");
        Assert.Equal(1 - stress, S(r, Objective.Water), 12);
        Assert.Equal(stress, r.Raw[Objective.Water], 12);
    }

    [Fact]
    public void WaterIsPerfectWithoutStress() => Assert.Equal(1.0, S(Score("cerealB"), Objective.Water), 12);

    [Fact]
    public void PenaltiesAreSubtractedFromSurvival()
    {
        // penalty response on p1 (curve y = x, weight 0.1): (1 - 0.2) * 0.1 = 0.08 in the last season
        var kb = WithCrop(Kb, "cerealB", c => c with
        {
            Responses =
            [
                .. c.Responses,
                new Response { Var = new StateVarId("pathogen:p1"), Curve = Curve.Create([new(0, 0), new(1, 1)]), Target = ResponseTarget.Penalty, Weight = 0.1 }
            ]
        });

        var r = Score(Env(kb), ["cerealB"]);

        Assert.Equal(StaticCerealB * 0.86 - 0.08, S(r, Objective.Survival), 9);
    }

    [Fact]
    public void SurvivalCannotGoBelowZero()
    {
        var kb = WithCrop(Kb, "cerealB", c => c with
        {
            Responses =
            [
                .. c.Responses,
                new Response { Var = new StateVarId("pathogen:p1"), Curve = Curve.Constant(0), Target = ResponseTarget.Penalty, Weight = 5 }
            ]
        });

        var r = Score(Env(kb), ["cerealB"]);

        Assert.Equal(0, S(r, Objective.Survival));
        Assert.True(r.Raw[Objective.Survival] < 0);
    }

    [Fact]
    public void GrossMarginIsMissingAndEverythingElseIsPresent()
    {
        var r = Score("cerealA", "legumeA");

        Assert.DoesNotContain(Objective.GrossMargin, r.Scores.Values.Keys);
        Assert.Equal(7, r.Scores.Values.Count);
        Assert.All(r.Scores.Values.Values, v => Assert.InRange(v, 0, 1));
    }

    [Fact]
    public void TransitionSeasonsDoNotChangeTheCycleScores()
    {
        var plain = Score(Env(), ["cerealB"]);
        var withTransition = Score(Env(), ["cerealB"], ["oilseedA"]);

        foreach (var o in plain.Scores.Values.Keys)
            Assert.Equal(plain.Scores[o], withTransition.Scores[o], 9);
    }

    [Fact]
    public void TransitionSeasonsCountForTheWorstSeasonSurvival()
    {
        var plain = Score(Env(), ["cerealB"]);
        var withTransition = Score(Env(), ["cerealB"], ["oilseedA"]);

        Assert.Equal(StaticCerealB, plain.WorstSeasonCvar, 9);
        Assert.Equal(0.375, withTransition.WorstSeasonCvar, 9);
    }

    [Fact]
    public void OneReasonPerScoredObjectiveWithTheNumbersBehindIt()
    {
        var r = Score("cerealB");

        Assert.Equal(7, r.Reasons.Count);
        Assert.All(r.Reasons, x => Assert.Equal(ReasonKind.Objective, x.Kind));
        var humus = Assert.Single(r.Reasons, x => x.Code == "objective.humus");
        Assert.Equal(S(r, Objective.Humus), humus.Value!.Value, 12);
        Assert.Equal(S(r, Objective.Humus) - 1, humus.Delta, 12);
        Assert.Contains("40", humus.Message);
        Assert.DoesNotContain(r.Reasons, x => x.Code == "objective.grossmargin");
    }

    [Fact]
    public void ABetterRotationDominatesAWorseOne()
    {
        var mono = Score("cerealB");
        var rotated = Score("legumeA", "cerealA");

        Assert.True(S(rotated, Objective.Nitrogen) > S(mono, Objective.Nitrogen));
        Assert.True(S(rotated, Objective.Humus) > S(mono, Objective.Humus));
        Assert.True(S(rotated, Objective.Cover) > S(mono, Objective.Cover));
    }

    [Fact]
    public void ABreakCropLowersPathogenPressureComparedWithAStrongHostMonoculture()
    {
        // With two unrolled cycles the scored cycle is the second one, so pressure has had only one earlier cycle
        // to build up (the true limit of a monoculture would be 0.5 / (1 - 0.4) = 0.833).
        // cerealA monoculture: p1 = 0.5 before the scored season.
        // legumeA + cerealA: legumeA reads p2 = 0.5 * 0.5 = 0.25 and cerealA reads p1 = 0.5 * 0.4 = 0.2 -> mean 0.225.
        var mono = Score("cerealA");
        var rotated = Score("legumeA", "cerealA");

        Assert.Equal(0.5, mono.Raw[Objective.Pathogen], 9);
        Assert.Equal(0.225, rotated.Raw[Objective.Pathogen], 9);
        Assert.True(S(rotated, Objective.Pathogen) > S(mono, Objective.Pathogen));
    }

    [Fact]
    public void ScoringIsDeterministic()
    {
        var a = Score("cerealA", "legumeA", "rootCropA");
        var b = Score("cerealA", "legumeA", "rootCropA");

        Assert.Equal(a.Scores.Values.OrderBy(v => v.Key), b.Scores.Values.OrderBy(v => v.Key));
        Assert.Equal(a.Reasons.Select(r => r.Message), b.Reasons.Select(r => r.Message));
    }
}

public class PlanSimulatorTests
{
    [Fact]
    public void UnrollsTransitionAndRepeatedCycleWithIndicesAndYears()
    {
        var env = Env();
        var plan = new RotationPlan
        {
            FirstHarvestYear = 2030,
            Transition = [Season("legumeA")],
            Cycle = [Season("cerealA"), Season("cerealB")]
        };

        var sim = PlanSimulator.Simulate(plan, env.InitialState(), env);

        // settings: unrollCycles = 2 -> 1 transition + 2 x 2 = 5 seasons
        Assert.Equal(5, sim.Seasons.Count);
        Assert.Equal([0, 1, 2, 3, 4], sim.Seasons.Select(s => s.Index));
        Assert.Equal([2030, 2031, 2032, 2033, 2034], sim.Seasons.Select(s => s.HarvestYear));
        Assert.Equal([true, false, false, false, false], sim.Seasons.Select(s => s.IsTransition));
        Assert.Equal(3, sim.LastCycleStart);
        Assert.Equal(["cerealA", "cerealB"], sim.CycleSeasons.Select(s => s.Plan.MainCrop.Value));
    }

    [Fact]
    public void CarriesTheStateFromSeasonToSeason()
    {
        var env = Env();
        var plan = new RotationPlan { FirstHarvestYear = 2030, Cycle = [Season("legumeA"), Season("cerealA")] };

        var sim = PlanSimulator.Simulate(plan, env.InitialState(), env);

        Assert.Equal(40, V(sim.Seasons[1].Step.Evaluation.StateBefore, "residualN"));
        Assert.Equal(V(sim.Seasons[0].Step.Next.Soil, "humusC"), V(sim.Seasons[1].Step.Evaluation.StateBefore, "humusC"));
    }

    [Fact]
    public void StartsFromTheSeededHistory()
    {
        var env = Env();
        var seeded = HistorySeeder.Seed(PlotWithHistory(new HistoricSeason { HarvestYear = 2029, Crop = new CropId("legumeA") }), env);
        var plan = new RotationPlan { FirstHarvestYear = 2030, Cycle = [Season("cerealA")] };

        var sim = PlanSimulator.Simulate(plan, seeded.State, env);

        Assert.Equal(40, V(sim.Seasons[0].Step.Evaluation.StateBefore, "residualN"));
    }

    [Fact]
    public void RejectsAnEmptyCycle()
    {
        var env = Env();

        Assert.Throws<ArgumentException>(() =>
            PlanSimulator.Simulate(new RotationPlan { FirstHarvestYear = 2030, Cycle = [] }, env.InitialState(), env));
    }

    [Fact]
    public void EvaluatorProducesAPlanEvaluationWithAllTheParts()
    {
        var env = Env();
        var plan = new RotationPlan { FirstHarvestYear = 2030, Cycle = [Season("legumeA"), Season("cerealA")] };

        var evaluation = PlanEvaluator.Evaluate(plan, env.InitialState(), env);

        Assert.Equal(4, evaluation.Seasons.Count);
        Assert.True(evaluation.IsFeasible);
        Assert.Contains(evaluation.Reasons, r => r.Kind == ReasonKind.StateEffect);
        Assert.Contains(evaluation.Reasons, r => r.Code == "objective.survival");
        Assert.Equal(7, evaluation.Scores.Values.Count);
    }
}

public class ObjectiveSettingsTests
{
    [Theory]
    [InlineData(0, 3)]
    [InlineData(-1, 3)]
    [InlineData(0.5, 0)]
    public void RejectsImplausibleRootDepthSettings(double width, int classes)
    {
        var settings = Settings with
        {
            Objectives = Settings.Objectives with { RootDepthClassM = width, RootDepthClassesForFullScore = classes }
        };

        var report = Engine.Validation.KnowledgeBaseValidator.Validate(Kb, settings);

        Assert.True(report.HasError("settings.objectives"));
    }
}
