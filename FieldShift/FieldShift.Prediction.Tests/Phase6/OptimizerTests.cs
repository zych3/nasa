using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Searching;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase6;

public class OptimizerTests
{
    private static RotationPlan Plan(params string[] cycle) => new()
    {
        FirstHarvestYear = 2026,
        Cycle = cycle.Select(c => Season(c)).ToList()
    };

    private static OptimizedPlan Optimize(
        RotationPlan plan, Strategy strategy, CropKnowledgeBase? kb = null, FarmerInputs? farmer = null, bool catchCrops = true,
        EngineSettings? settings = null)
    {
        kb ??= Kb;
        var env = Env(kb, farmer, settings);
        var catches = catchCrops ? kb.CatchCrops : [];
        return new CatchCropAndActionOptimizer(env, env.InitialState(), strategy, catches).Optimize(plan);
    }

    private static readonly Strategy SoilHealth = Strat("soil", floor: 0.3, minL: 3, maxL: 5,
        weights: [(Objective.Cover, 0.5), (Objective.Humus, 0.3), (Objective.Survival, 0.2)]);

    private static double Score(RotationPlan plan, Strategy strategy, CropKnowledgeBase? kb = null, FarmerInputs? farmer = null)
    {
        var env = Env(kb, farmer);
        var scores = PlanEvaluator.Evaluate(plan, env.InitialState(), env, collectReasons: false).Scores;
        var weights = StrategySelector.Weights(strategy, Engine.Objectives.ObjectiveScorer.Scored);
        return StrategySelector.WeightedScore(weights, Engine.Objectives.ObjectiveScorer.Scored.Select(o => scores[o]).ToArray());
    }

    [Fact]
    public void AddsCatchCropsWhereTheyFitAndHelp()
    {
        var original = Plan("cerealB", "legumeA", "rootCropA");

        var result = Optimize(original, SoilHealth);

        Assert.Equal([new CropId("catchA"), new CropId("catchA"), default(CropId?)], result.Plan.Cycle.Select(s => s.CatchCrop).ToArray());
        Assert.True(result.AcceptedChanges >= 2);
        Assert.True(result.Score > Score(original, SoilHealth));
    }

    [Fact]
    public void NeverPlacesACatchCropBeforeAWinterCrop()
    {
        var result = Optimize(Plan("cerealB", "cerealA", "legumeA"), SoilHealth);

        Assert.Null(result.Plan.Cycle[0].CatchCrop);
        Assert.Equal(new CropId("catchA"), result.Plan.Cycle[1].CatchCrop);
        Assert.Equal(new CropId("catchA"), result.Plan.Cycle[2].CatchCrop);
    }

    [Fact]
    public void AStrategyThatDoesNotCareLeavesThePlanAlone()
    {
        var survivalOnly = Strat("survival", minL: 3, maxL: 5, weights: [(Objective.Survival, 1.0)]);
        var original = Plan("cerealB", "legumeA", "rootCropA");

        var result = Optimize(original, survivalOnly);

        Assert.Equal(0, result.AcceptedChanges);
        Assert.All(result.Plan.Cycle, s => Assert.Null(s.CatchCrop));
        Assert.All(result.Plan.Cycle, s => Assert.Empty(s.Actions));
    }

    [Fact]
    public void WithoutCatchCropCandidatesNothingIsAdded()
    {
        var result = Optimize(Plan("cerealB", "legumeA", "rootCropA"), SoilHealth, catchCrops: false);

        Assert.All(result.Plan.Cycle, s => Assert.Null(s.CatchCrop));
    }

    [Fact]
    public void TransitionSeasonsGetNoCatchCropBecauseObjectivesIgnoreThem()
    {
        var plan = new RotationPlan
        {
            FirstHarvestYear = 2026,
            Transition = [Season("cerealB")],
            Cycle = [Season("legumeA"), Season("cerealB"), Season("rootCropA")]
        };

        var result = Optimize(plan, SoilHealth);

        Assert.Null(result.Plan.Transition[0].CatchCrop);
        Assert.Equal(new CropId("catchA"), result.Plan.Cycle[0].CatchCrop);
    }

    private static CropKnowledgeBase WithManure(string? requirement) => WithExtraAction(Kb, new ManagementActionDefinition
    {
        Id = new ActionId("manure"),
        NamePl = "Obornik",
        RequiresFarmerInput = requirement,
        Effects = [Eff("residualN", EffectOp.Add, 50)],
        Sources = [new SourceRef { Id = "S1" }]
    });

    private static readonly Strategy NitrogenFirst = Strat("n", minL: 3, maxL: 5, weights: [(Objective.Nitrogen, 1.0)]);

    [Fact]
    public void AddsAnActionTheFarmerCanDoWhenItHelps()
    {
        var kb = WithManure("farmer.hasLivestockOrManure");
        var original = Plan("legumeA", "cerealA", "rootCropA");

        var result = Optimize(original, NitrogenFirst, kb, new FarmerInputs { HasLivestockOrManure = true }, catchCrops: false);

        Assert.Contains(result.Plan.Cycle, s => s.Actions.Any(a => a.Action.Value == "manure"));
        Assert.True(result.Score > Score(original, NitrogenFirst, kb, new FarmerInputs { HasLivestockOrManure = true }));
    }

    [Fact]
    public void DoesNotOfferAnActionTheFarmerCannotDo()
    {
        var kb = WithManure("farmer.hasLivestockOrManure");

        var result = Optimize(Plan("legumeA", "cerealA", "rootCropA"), NitrogenFirst, kb, new FarmerInputs(), catchCrops: false);

        Assert.All(result.Plan.Cycle, s => Assert.Empty(s.Actions));
    }

    [Fact]
    public void ActionsWithoutRequirementsAreAlwaysOffered()
    {
        var kb = WithManure(null);

        var result = Optimize(Plan("legumeA", "cerealA", "rootCropA"), NitrogenFirst, kb, catchCrops: false);

        Assert.Contains(result.Plan.Cycle, s => s.Actions.Count > 0);
    }

    [Fact]
    public void UselessActionsAreLeftOut()
    {
        var result = Optimize(Plan("cerealB", "legumeA", "rootCropA"), NitrogenFirst, catchCrops: false);

        Assert.All(result.Plan.Cycle, s => Assert.Empty(s.Actions));
    }

    [Fact]
    public void RefusesAChangeThatWouldBreakTheSurvivalFloor()
    {
        var kb = WithCrop(Kb, "catchA", c => c with
        {
            Effects = [.. c.Effects, Eff("pathogen:p3", EffectOp.Load, 0.9), Eff("humusC", EffectOp.Add, 500)]
        });
        var strategy = Strat("risky", floor: 0.2, minL: 4, maxL: 4, weights: [(Objective.Cover, 0.5), (Objective.Humus, 0.5)]);
        var plan = Plan("oilseedA", "legumeA", "rootCropA", "cerealB");

        var env = Env(kb);
        var baseline = PlanEvaluator.Evaluate(plan, env.InitialState(), env, collectReasons: false);
        Assert.True(baseline.Seasons.All(s => s.SurvivalCvar20 >= 0.2), "the starting plan itself must respect the floor");

        var result = Optimize(plan, strategy, kb);

        Assert.Equal(0, result.AcceptedChanges);
        Assert.All(result.Plan.Cycle, s => Assert.Null(s.CatchCrop));
    }

    [Fact]
    public void ZeroPassesChangeNothing()
    {
        var settings = WithSearch(s => s with { LocalSearchPasses = 0 });

        var result = Optimize(Plan("cerealB", "legumeA", "rootCropA"), SoilHealth, settings: settings);

        Assert.Equal(0, result.AcceptedChanges);
    }

    [Fact]
    public void TheResultIsDeterministic()
    {
        var a = Optimize(Plan("cerealB", "legumeA", "rootCropA"), SoilHealth);
        var b = Optimize(Plan("cerealB", "legumeA", "rootCropA"), SoilHealth);

        Assert.Equal(a.Plan.Cycle.Select(s => s.CatchCrop), b.Plan.Cycle.Select(s => s.CatchCrop));
        Assert.Equal(a.Score, b.Score);
    }

    [Fact]
    public void TheMainCropsAreNeverTouched()
    {
        var original = Plan("cerealB", "legumeA", "rootCropA");

        var result = Optimize(original, SoilHealth);

        Assert.Equal(original.Cycle.Select(s => s.MainCrop), result.Plan.Cycle.Select(s => s.MainCrop));
    }
}
