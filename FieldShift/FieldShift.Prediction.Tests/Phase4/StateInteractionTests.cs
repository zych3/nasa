using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Loading;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Engine.Validation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase4;

public class StateInteractionTests
{
    private static StateInteraction Rule(
        string id, string triggerVar, Curve trigger, InteractionTargetKind kind, string targetVar,
        double multiplier, string? crops = null, EffectOp? op = null) => new()
    {
        Id = id,
        When = new InteractionTrigger { Var = new StateVarId(triggerVar), Curve = trigger },
        Target = new InteractionTarget { Kind = kind, Var = new StateVarId(targetVar), Op = op },
        Multiplier = multiplier,
        Crops = crops is null ? null : CropSelector.Parse(crops)
    };

    private static readonly Curve Always = Curve.Constant(1);
    private static readonly Curve Never = Curve.Constant(0);

    [Fact]
    public void EffectAmountIsScaledByTheMultiplierWhenTheTriggerIsFull()
    {
        var kb = WithStateInteractions(Kb,
            Rule("halfN", "ph", Always, InteractionTargetKind.Effect, "residualN", 0.5, "legumeA", EffectOp.Add));
        var env = Env(kb);

        var state = Run(env, env.InitialState(), "legumeA").State.Soil;

        Assert.Equal(20, V(state, "residualN"), 9); // 40 x 0.5
    }

    [Fact]
    public void NothingChangesWhileTheTriggerIsZero()
    {
        var plain = Run(Env(), Env().InitialState(), "legumeA").State.Soil;
        var kb = WithStateInteractions(Kb,
            Rule("off", "ph", Never, InteractionTargetKind.Effect, "residualN", 0.5, "legumeA"));
        var env = Env(kb);

        var state = Run(env, env.InitialState(), "legumeA").State.Soil;

        Assert.Equal(V(plain, "residualN"), V(state, "residualN"), 9);
    }

    [Fact]
    public void TheFactorRampsLinearlyWithTheTrigger()
    {
        // ph of the fixture plot is read at the start of the season; trigger 0.5 -> factor 1 + (3 - 1) x 0.5 = 2.
        var half = Curve.Constant(0.5);
        var kb = WithStateInteractions(Kb, Rule("ramp", "ph", half, InteractionTargetKind.Effect, "residualN", 3, "legumeA"));
        var env = Env(kb);

        var state = Run(env, env.InitialState(), "legumeA").State.Soil;

        Assert.Equal(80, V(state, "residualN"), 9);
    }

    [Fact]
    public void RulesOnTheSameTargetMultiplyAndAreCapped()
    {
        var kb = WithStateInteractions(Kb,
            Rule("a", "ph", Always, InteractionTargetKind.Effect, "residualN", 2, "legumeA"),
            Rule("b", "ph", Always, InteractionTargetKind.Effect, "residualN", 2, "legumeA"));
        var env = Env(kb);

        var capped = Run(env, env.InitialState(), "legumeA").State.Soil;

        // 2 x 2 = 4, capped at maxMultiplier 3 -> 40 x 3
        Assert.Equal(120, V(capped, "residualN"), 9);
    }

    [Fact]
    public void RuleOnlyAffectsCropsMatchingTheSelector()
    {
        var kb = WithStateInteractions(Kb,
            Rule("cerealOnly", "ph", Always, InteractionTargetKind.Effect, "residualN", 0.5, "tag:cereal"));
        var env = Env(kb);
        var plain = Run(Env(), Env().InitialState(), "legumeA").State.Soil;

        var state = Run(env, env.InitialState(), "legumeA").State.Soil;

        Assert.Equal(V(plain, "residualN"), V(state, "residualN"), 9);
    }

    [Fact]
    public void ResponseLossIsScaledNotTheCurveItself()
    {
        var kb = WithStateInteractions(Kb,
            Rule("worseP1", "residualN", Always, InteractionTargetKind.Response, "pathogen:p1", 2, "cerealA"));
        var env = Env(kb);

        var yield = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1].Evaluation.YieldFactor;

        // p1 curve 0.7 -> loss 0.3 x 2 -> 0.4; residualN curve stays 0.7; override -0.1 (see SeasonSimulatorEvaluationTests)
        Assert.Equal(0.4 * 0.7 - 0.1, yield, 9);
    }

    [Fact]
    public void ResponseLossAtTheCapLeavesTenPercentOfTheCurve()
    {
        var kb = WithStateInteractions(WithInteractions(Kb, []),
            Rule("harsh", "residualN", Always, InteractionTargetKind.Response, "residualN", 3, "cerealA"));
        var env = Env(kb);

        var yield = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1].Evaluation.YieldFactor;

        // residualN curve 0.7 -> loss 0.3 x 3 = 0.9 -> 0.1; p1 curve stays 0.7; no previous-crop override
        Assert.Equal(0.1 * 0.7, yield, 9);
    }

    [Fact]
    public void AFiringRuleIsExplainedWithItsFactor()
    {
        var kb = WithStateInteractions(Kb,
            Rule("halfN", "ph", Always, InteractionTargetKind.Effect, "residualN", 0.5, "legumeA"));
        var env = Env(kb);

        var step = Run(env, env.InitialState(), "legumeA").Steps[0];

        var reason = Assert.Single(step.Reasons, r => r.Kind == ReasonKind.StateInteraction);
        Assert.Equal("interaction.rule.halfN", reason.Code);
        Assert.Equal(0.5, reason.Value!.Value, 9);
        Assert.Equal(-20, reason.Delta, 9);
    }

    [Fact]
    public void SearchModeGivesTheSameStateAsExplainMode()
    {
        var kb = WithStateInteractions(Kb,
            Rule("halfN", "ph", Always, InteractionTargetKind.Effect, "residualN", 0.5, "legumeA"),
            Rule("worseP1", "residualN", Always, InteractionTargetKind.Response, "pathogen:p1", 2, "cerealA"));
        var env = Env(kb);
        var state = env.InitialState();

        var explained = SeasonSimulatorFor(env, state, collect: true);
        var fast = SeasonSimulatorFor(env, state, collect: false);

        Assert.Equal(V(explained, "residualN"), V(fast, "residualN"), 12);
    }

    private static SoilState SeasonSimulatorFor(SimEnvironment env, SimState start, bool collect)
    {
        var step = SeasonSimulator.Step(start, new SeasonContext
        {
            SeasonIndex = 0, HarvestYear = 2030, Season = Season("legumeA"), Env = env, CollectReasons = collect
        });
        return step.Next.Soil;
    }

    [Fact]
    public void ValidationRejectsUnknownVariablesBadMultipliersAndBadOps()
    {
        var kb = WithStateInteractions(Kb,
            Rule("a", "nope", Always, InteractionTargetKind.Effect, "residualN", 2),
            Rule("b", "ph", Always, InteractionTargetKind.Effect, "nope", 2),
            Rule("c", "ph", Always, InteractionTargetKind.Effect, "residualN", 0),
            Rule("d", "ph", Always, InteractionTargetKind.Effect, "residualN", 99),
            Rule("e", "ph", Always, InteractionTargetKind.Effect, "residualN", 2, op: EffectOp.Set),
            Rule("f", "ph", Always, InteractionTargetKind.Response, "residualN", 2, op: EffectOp.Add),
            Rule("a", "ph", Always, InteractionTargetKind.Effect, "residualN", 2));

        var report = KnowledgeBaseValidator.Validate(kb, Settings);

        var codes = report.Errors.Select(e => e.Code).ToList();
        Assert.Contains("stateInteraction.unknownTrigger", codes);
        Assert.Contains("stateInteraction.unknownTarget", codes);
        Assert.Contains("stateInteraction.multiplier", codes);
        Assert.Contains("stateInteraction.op", codes);
        Assert.Contains("stateInteraction.id", codes);
    }

    [Fact]
    public void ValidationWarnsWhenARuleCanNeverFire()
    {
        var never = WithStateInteractions(Kb,
            Rule("deadRule", "ph", Always, InteractionTargetKind.Effect, "mycorrhiza", 2, "catchA"));
        var report = KnowledgeBaseValidator.Validate(never, Settings);

        Assert.Contains(report.Warnings, w => w.Code == "stateInteraction.noTarget");
    }

    [Fact]
    public void ShippedRulesLoadAndValidate()
    {
        var loaded = KnowledgeBaseLoader.Load(Path.Combine(AppContext.BaseDirectory, "Data"));

        Assert.True(loaded.Succeeded, loaded.Report.ToString());
        Assert.NotEmpty(loaded.KnowledgeBase!.StateInteractions);
        Assert.DoesNotContain(loaded.Report.Warnings, w => w.Code == "stateInteraction.noTarget");
    }
}
