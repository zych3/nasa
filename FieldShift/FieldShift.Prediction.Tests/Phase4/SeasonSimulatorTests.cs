using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase4;

public class SeasonSimulatorEvaluationTests
{
    [Fact]
    public void CerealAfterCerealScoresLowerThanCerealAfterLegume()
    {
        var env = Env();
        var afterLegume = Run(env, env.InitialState(), "legumeA", "cerealA").Steps[1];
        var afterCereal = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1];

        // After legumeA: residualN 40 -> 0.7 + 0.3 * 40/60 = 0.9; no pathogen, pH in the optimum.
        Assert.Equal(0.9, afterLegume.Evaluation.YieldFactor, 9);
        // After cerealA: residualN 0 -> 0.7; p1 = 0.5 -> 0.7; minus the 0.1 cereal-after-cereal override.
        Assert.Equal(0.7 * 0.7 - 0.1, afterCereal.Evaluation.YieldFactor, 9);
        Assert.True(afterCereal.Evaluation.YieldFactor < afterLegume.Evaluation.YieldFactor);
    }

    [Fact]
    public void SurvivalResponsesMultiplyTheStaticSurvivalOfEveryYear()
    {
        var env = Env();
        var staticMean = env.Survival![new CropId("oilseedA")].Mean;

        var first = Run(env, env.InitialState(), "oilseedA", "oilseedA").Steps;

        Assert.Equal(staticMean, first[0].Evaluation.SurvivalMean, 9);
        // p3 = 0.6 after one oilseed season; curve (0,1) (0.3,0.6) (1,0.1) -> 0.6 - 0.5 * 0.3/0.7
        var multiplier = 0.6 - 0.5 * (0.3 / 0.7);
        Assert.Equal(staticMean * multiplier, first[1].Evaluation.SurvivalMean, 9);
        Assert.Equal(staticMean * multiplier, first[1].Evaluation.SurvivalCvar20, 9);
    }

    [Fact]
    public void ResponseWeightIsAnExponent()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with
        {
            Responses = c.Responses.Select(r => r.Var.Value == "pathogen:p1" ? r with { Weight = 2 } : r).ToList()
        });
        var env = Env(kb);

        var yield = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1].Evaluation.YieldFactor;

        Assert.Equal(Math.Pow(0.7, 2) * 0.7 - 0.1, yield, 9);
    }

    [Fact]
    public void PenaltyIsTheWeightedShortfall()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with
        {
            Responses =
            [
                .. c.Responses,
                new Response { Var = new StateVarId("residualN"), Curve = Curve.Create([new(0, 0), new(60, 1)]), Target = ResponseTarget.Penalty, Weight = 2 }
            ]
        });
        var env = Env(kb);

        var step = Run(env, env.InitialState(), "legumeA", "cerealA").Steps[1];

        // residualN 40 -> curve 2/3 -> penalty (1 - 2/3) * 2
        Assert.Equal(2.0 / 3.0, step.Detail.Penalty, 9);
        Assert.Contains(step.Reasons, r => r.Code == "response.residualN.penalty");
    }

    [Theory]
    [InlineData(ResponseTarget.Survival)]
    [InlineData(ResponseTarget.Penalty)]
    public void OverridesAreAddedToTheTargetTheyName(ResponseTarget target)
    {
        var kb = WithInteractions(Kb,
        [
            new InteractionOverride
            {
                Prev = CropSelector.Parse("cerealA"), Next = CropSelector.Parse("cerealA"),
                Delta = target == ResponseTarget.Survival ? -0.1 : 0.5, Target = target, Reason = "test"
            }
        ]);
        var env = Env(kb);
        var staticMean = env.Survival![new CropId("cerealA")].Mean;

        var step = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1];

        if (target == ResponseTarget.Survival)
            Assert.Equal(staticMean - 0.1, step.Evaluation.SurvivalMean, 9);
        else
            Assert.Equal(0.5, step.Detail.Penalty, 9);
    }

    [Fact]
    public void OverrideDoesNotApplyAfterANonMatchingCrop()
    {
        var env = Env();

        var step = Run(env, env.InitialState(), "legumeA", "cerealA").Steps[1];

        Assert.DoesNotContain(step.Reasons, r => r.Kind == ReasonKind.InteractionOverride);
    }

    [Fact]
    public void EmitsOneReasonPerResponseBelowThreshold()
    {
        var env = Env();

        var step = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1];

        var p1 = Assert.Single(step.Reasons, r => r.Code == "response.pathogen:p1");
        Assert.Equal(0.5, p1.Value!.Value, 9);
        Assert.Equal(0.7 - 1, p1.Delta, 9);
        Assert.Equal(ReasonKind.StateResponse, p1.Kind);
        Assert.Equal(1, p1.SeasonIndex);
        Assert.DoesNotContain(step.Reasons, r => r.Code == "response.ph");
        Assert.Contains(step.Reasons, r => r.Code == "response.residualN");
    }

    [Fact]
    public void ResponseReasonsNameTheSeasonsThatCausedTheState()
    {
        var env = Env();

        var step = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1];

        var p1 = step.Reasons.Single(r => r.Code == "response.pathogen:p1");
        Assert.Equal([new Cause(0, new CropId("cerealA"))], p1.CausedBy);
    }

    [Fact]
    public void TheLargestContributionComesFirstInCausedBy()
    {
        var env = Env();

        var (state, _) = Run(env, env.InitialState(), "cerealA", "legumeA", "cerealB");

        var causes = state.Ledger.Top(new StateVarId("pathogen:p1"), 3);
        Assert.Equal([new Cause(2, new CropId("cerealB")), new Cause(0, new CropId("cerealA"))], causes);
    }

    [Fact]
    public void InteractionReasonPointsAtThePreviousCrop()
    {
        var env = Env();

        var step = Run(env, env.InitialState(), "cerealA", "cerealA").Steps[1];

        var r = Assert.Single(step.Reasons, x => x.Kind == ReasonKind.InteractionOverride);
        Assert.Equal("interaction.yield", r.Code);
        Assert.Equal(-0.1, r.Delta, 9);
        Assert.Equal([new Cause(0, new CropId("cerealA"))], r.CausedBy);
    }

    [Fact]
    public void WaterStressDetailIsTheMeanOverClimateYears()
    {
        var env = Env();
        var years = env.Survival![new CropId("cerealB")].Years;

        var step = Run(env, env.InitialState(), "cerealB").Steps[0];

        Assert.Equal(years.Average(y => y.Factors.WaterStress), step.Detail.MeanWaterStress, 12);
        Assert.Equal(years.Count, step.Detail.YearSurvival.Count);
    }

    [Fact]
    public void StateBeforeAndAfterAreRecorded()
    {
        var env = Env();
        var start = env.InitialState();

        var step = Run(env, start, "legumeA").Steps[0];

        Assert.Equal(0, V(step.Evaluation.StateBefore, "residualN"));
        Assert.Equal(40, V(step.Evaluation.StateAfter, "residualN"));
        Assert.Equal(new CropId("legumeA"), step.Evaluation.Crop);
        Assert.Equal(new CropId("legumeA"), step.Next.PreviousMainCrop);
    }

    [Fact]
    public void WithoutSurvivalEvaluationOnlyEffectsApply()
    {
        var env = Env(withSurvival: false);

        var step = Step(env, env.InitialState(), Season("legumeA"), evaluate: false);

        Assert.False(step.Detail.Evaluated);
        Assert.Equal(40, V(step.Next.Soil, "residualN"));
        Assert.DoesNotContain(step.Reasons, r => r.Kind is ReasonKind.StateResponse or ReasonKind.InteractionOverride);
    }

    [Fact]
    public void EvaluatingWithoutAStaticSurvivalTableIsAnError()
    {
        var env = Env(withSurvival: false);

        Assert.Throws<InvalidOperationException>(() => Step(env, env.InitialState(), Season("legumeA")));
    }
}

public class SeasonSimulatorStateTests
{
    private static SimEnvironment EnvWith(Func<CropKnowledgeBase, CropKnowledgeBase> change, FarmerInputs? farmer = null) =>
        Env(change(Kb), farmer);

    private static CropKnowledgeBase AddCerealAEffects(CropKnowledgeBase kb, params Effect[] extra) =>
        WithCrop(kb, "cerealA", c => c with { Effects = [.. c.Effects, .. extra] });

    private static readonly double H0 = 15.3 * 1.4 * 0.3 * 10_000;

    [Fact]
    public void EventsResetBetweenSeasons()
    {
        var env = Env();

        var steps = Run(env, env.InitialState(), "cerealA", "legumeA").Steps;

        Assert.Equal(0.8, V(steps[0].Next.Soil, "soilCoverWinter"), 9);
        Assert.Equal(0.8, V(steps[1].Evaluation.StateBefore, "soilCoverWinter"), 9);
        Assert.Equal(0, V(steps[1].Next.Soil, "soilCoverWinter"), 9);
    }

    [Fact]
    public void PoolsAreConsumedByTheMainCrop()
    {
        var env = Env();

        var steps = Run(env, env.InitialState(), "legumeA", "cerealB").Steps;

        Assert.Equal(40, V(steps[1].Evaluation.StateBefore, "residualN"));
        Assert.Equal(0, V(steps[1].Next.Soil, "residualN"));
    }

    [Fact]
    public void StocksAndPressuresAreNotReset()
    {
        var env = Env();

        var (state, _) = Run(env, env.InitialState(), "cerealA", "cerealB");

        Assert.Equal(H0 + 50 + 40, V(state.Soil, "humusC"), 6);
        Assert.True(V(state.Soil, "pathogen:p1") > 0);
    }

    [Fact]
    public void EffectsApplyInTheOrderMainCatchAction()
    {
        // humus: cerealA adds 50, catch crop multiplies by 2, the action adds 10 -> (H0 + 50) * 2 + 10
        var kb = WithAction(WithCrop(Kb, "catchA", c => c with { Effects = [Eff("humusC", EffectOp.Multiply, 2)] }),
            "lime", a => a with { Effects = [Eff("humusC", EffectOp.Add, 10)] });
        var env = Env(kb);

        var step = Step(env, env.InitialState(),
            Season("cerealA", "catchA", null, new PlannedAction(new ActionId("lime"))));

        Assert.Equal((H0 + 50) * 2 + 10, V(step.Next.Soil, "humusC"), 6);
        var humusDeltas = step.Reasons.Where(r => r.Code == "effect.humusC").Select(r => r.Delta).ToList();
        Assert.Equal(new[] { 50.0, Math.Round(H0 + 50, 6), 10.0 }, humusDeltas.Select(d => Math.Round(d, 6)));
    }

    [Fact]
    public void AddMultiplyAndSetBehaveAsNamed()
    {
        var env = EnvWith(kb => AddCerealAEffects(kb,
            Eff("humusC", EffectOp.Multiply, 0.5), Eff("recentLiming", EffectOp.Set, 0.7)));

        var step = Step(env, env.InitialState(), Season("cerealA"));

        Assert.Equal((H0 + 50) * 0.5, V(step.Next.Soil, "humusC"), 6);
        Assert.Equal(0.7, V(step.Next.Soil, "recentLiming"), 9);
    }

    [Fact]
    public void ValuesAreClampedToTheVariableRange()
    {
        var env = EnvWith(kb => AddCerealAEffects(kb,
            Eff("humusC", EffectOp.Add, -1e9), Eff("ph", EffectOp.Add, 10)));

        var step = Step(env, env.InitialState(), Season("cerealA"));

        Assert.Equal(0, V(step.Next.Soil, "humusC"));
        Assert.Equal(8.5, V(step.Next.Soil, "ph"));
    }

    [Fact]
    public void ScaleByNRateFollowsTheActualRate()
    {
        var env = EnvWith(kb => AddCerealAEffects(kb, Eff("humusC", EffectOp.Add, 100, scaleBy: "management.nRate")));

        var normal = Step(env, env.InitialState(), Season("cerealA"));
        var half = Step(env, env.InitialState(), Season("cerealA"), nRate: 75);

        Assert.Equal(H0 + 50 + 100, V(normal.Next.Soil, "humusC"), 6);
        Assert.Equal(H0 + 50 + 50, V(half.Next.Soil, "humusC"), 6);
    }

    [Fact]
    public void ScaleByNRateIsNeutralForACropWithoutNitrogen()
    {
        var kb = WithCrop(Kb, "legumeA", c => c with { Effects = [.. c.Effects, Eff("humusC", EffectOp.Add, 10, scaleBy: "management.nRate")] });
        var env = Env(kb);

        var step = Step(env, env.InitialState(), Season("legumeA"), nRate: 100);

        Assert.Equal(H0 + 80 + 10, V(step.Next.Soil, "humusC"), 6);
    }

    [Theory]
    [InlineData(ResidueHandling.Remove, true)]
    [InlineData(ResidueHandling.Mulch, false)]
    [InlineData(null, false)]
    public void ResidueConditionFollowsThePlan(ResidueHandling? residue, bool applies)
    {
        var env = EnvWith(kb => AddCerealAEffects(kb, Eff("humusC", EffectOp.Add, 100, when: "residue.remove")));

        var step = Step(env, env.InitialState(), Season("cerealA", residue: residue));

        Assert.Equal(H0 + 50 + (applies ? 100 : 0), V(step.Next.Soil, "humusC"), 6);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void FarmerConditionsReadTheFarmerInputs(bool hasManure)
    {
        var env = EnvWith(kb => AddCerealAEffects(kb, Eff("humusC", EffectOp.Add, 100, when: "farmer.hasLivestockOrManure")),
            new FarmerInputs { HasLivestockOrManure = hasManure });

        var step = Step(env, env.InitialState(), Season("cerealA"));

        Assert.Equal(H0 + 50 + (hasManure ? 100 : 0), V(step.Next.Soil, "humusC"), 6);
    }

    [Fact]
    public void LoadsWaitInTheBufferUntilTheEndOfTheSeason()
    {
        // The multiply acts on the state *before* the load: p1 = 0.5 -> 0, then 0 * 0.4 + 0.2 = 0.2.
        // If the load were applied at once the result would be (0.5 + 0.2) * 0 * 0.4 = 0.
        var kb = WithCrop(Kb, "cerealB", c => c with
        {
            Effects = [Eff("pathogen:p1", EffectOp.Load, 0.2), Eff("pathogen:p1", EffectOp.Multiply, 0)]
        });
        var env = Env(kb);
        var afterCerealA = Step(env, env.InitialState(), Season("cerealA")).Next;

        var step = Step(env, afterCerealA, Season("cerealB"), 1);

        Assert.Equal(0.2, V(step.Next.Soil, "pathogen:p1"), 9);
    }

    [Fact]
    public void PressureIsDecayedThenLoaded()
    {
        var env = Env();
        var afterCerealA = Step(env, env.InitialState(), Season("cerealA")).Next;

        var step = Step(env, afterCerealA, Season("cerealB"), 1);

        Assert.Equal(0.5 * 0.4 + 0.2, V(step.Next.Soil, "pathogen:p1"), 9);
    }

    [Fact]
    public void PressureCannotExceedItsMaximum()
    {
        var kb = WithCrop(Kb, "cerealB", c => c with { Effects = [Eff("pathogen:p1", EffectOp.Load, 5)] });
        var env = Env(kb);

        var step = Step(env, env.InitialState(), Season("cerealB"));

        Assert.Equal(1, V(step.Next.Soil, "pathogen:p1"));
    }

    [Fact]
    public void PressureDecaysWithoutAHostAndExplainsIt()
    {
        var env = Env();
        var afterCerealA = Step(env, env.InitialState(), Season("cerealA")).Next;

        var step = Step(env, afterCerealA, Season("legumeA"), 1);

        Assert.Equal(0.5 * 0.4, V(step.Next.Soil, "pathogen:p1"), 9);
        var decay = Assert.Single(step.Reasons, r => r.Code == "decay.pathogen:p1");
        Assert.Equal(ReasonKind.Decay, decay.Kind);
        Assert.Equal(0.5 * (0.4 - 1), decay.Delta, 9);
    }

    [Fact]
    public void SlowDecayKeepsAPressureForYears()
    {
        var env = Env();

        var (state, _) = Run(env, env.InitialState(), "oilseedA", "cerealB", "cerealB", "cerealB");

        // p3: 0.6 * 0.8^3
        Assert.Equal(0.6 * Math.Pow(0.8, 3), V(state.Soil, "pathogen:p3"), 9);
    }

    [Fact]
    public void AcidificationLowersPhThroughTheBufferAndIsReset()
    {
        // Buffer = 1000 + 80 * 9 + 40 * 15.3 = 2332 kg CaO per pH unit, so +233.2 lowers pH by 0.1.
        var kb = WithAction(Kb, "lime", a => a with { Effects = [Eff("acidificationCaO", EffectOp.Add, 233.2)] });
        var env = Env(kb);

        var step = Step(env, env.InitialState(), Season("cerealA", null, null, new PlannedAction(new ActionId("lime"))));

        Assert.Equal(5.75 - 0.1, V(step.Next.Soil, "ph"), 9);
        Assert.Equal(0, V(step.Next.Soil, "acidificationCaO"));
        var t = Assert.Single(step.Reasons, r => r.Code == "transform.ph");
        Assert.Equal(-0.1, t.Delta, 9);
    }

    [Fact]
    public void PhInheritsTheCausesOfTheAcidification()
    {
        var kb = WithAction(Kb, "lime", a => a with { Effects = [Eff("acidificationCaO", EffectOp.Add, 233.2)] });
        var env = Env(kb);

        var step = Step(env, env.InitialState(), Season("cerealA", null, null, new PlannedAction(new ActionId("lime"))), 4);

        Assert.Equal([new Cause(4, new CropId("cerealA"))], step.Next.Ledger.Top(StateVarId.Ph, 3));
        Assert.Empty(step.Next.Ledger.Top(StateVarId.AcidificationCaO, 3));
    }

    [Fact]
    public void LimingIsClampedByTheAcidificationRange()
    {
        // The fixture lime effect is -1000 but acidificationCaO cannot go below -500: pH rises by 500 / 2332.
        var env = Env();

        var step = Step(env, env.InitialState(), Season("cerealA", null, null, new PlannedAction(new ActionId("lime"))));

        Assert.Equal(5.75 + 500.0 / 2332.0, V(step.Next.Soil, "ph"), 9);
        Assert.Equal(1, V(step.Next.Soil, "recentLiming"));
    }

    [Fact]
    public void ActionAmountScalesItsAdditiveEffects()
    {
        var kb = WithAction(Kb, "lime", a => a with { Effects = [Eff("humusC", EffectOp.Add, 10)] });
        var env = Env(kb);

        var step = Step(env, env.InitialState(), Season("cerealA", null, null, new PlannedAction(new ActionId("lime"), 0.5)));

        Assert.Equal(H0 + 50 + 5, V(step.Next.Soil, "humusC"), 6);
    }

    [Fact]
    public void ActionWhoseRequirementFailsIsSkippedWithAReason()
    {
        var kb = WithAction(Kb, "lime", a => a with
        {
            Effects = [Eff("humusC", EffectOp.Add, 10)], RequiresFarmerInput = "farmer.hasIrrigation"
        });
        var env = Env(kb);

        var step = Step(env, env.InitialState(), Season("cerealA", null, null, new PlannedAction(new ActionId("lime"))));

        Assert.Equal(H0 + 50, V(step.Next.Soil, "humusC"), 6);
        Assert.Contains(step.Reasons, r => r.Code == "action.skipped.lime");
    }

    [Fact]
    public void UnknownActionIsSkippedWithAReason()
    {
        var env = Env();

        var step = Step(env, env.InitialState(), Season("cerealA", null, null, new PlannedAction(new ActionId("ghost"))));

        Assert.Contains(step.Reasons, r => r.Code == "action.unknown");
        Assert.Equal(H0 + 50, V(step.Next.Soil, "humusC"), 6);
    }

    [Fact]
    public void CertaintyScalesAdditiveEffectsAndLoads()
    {
        var env = Env(withSurvival: false);

        var step = Step(env, env.InitialState(), Season("legumeA"), certainty: 0.5, evaluate: false);

        Assert.Equal(20, V(step.Next.Soil, "residualN"), 9);              // 40 * 0.5
        Assert.Equal(0.25, V(step.Next.Soil, "pathogen:p2"), 9);          // load 0.5 * 0.5
        Assert.Equal(H0 + 40, V(step.Next.Soil, "humusC"), 6);            // 80 * 0.5
    }

    [Fact]
    public void CertaintyDoesNotScaleSetAndMultiply()
    {
        var env = EnvWith(kb => AddCerealAEffects(kb, Eff("recentLiming", EffectOp.Set, 1)));

        var step = Step(env, env.InitialState(), Season("cerealA"), certainty: 0.5, evaluate: true);

        Assert.Equal(1, V(step.Next.Soil, "recentLiming"));
    }

    [Fact]
    public void TheSameInputGivesTheSameOutput()
    {
        var env = Env();
        var season = Season("cerealA", "catchA", null, new PlannedAction(new ActionId("lime")));

        var a = Step(env, Run(env, env.InitialState(), "legumeA").State, season, 1);
        var b = Step(env, Run(env, env.InitialState(), "legumeA").State, season, 1);

        Assert.Equal(a.Next.Soil.Values.OrderBy(v => v.Key.Value), b.Next.Soil.Values.OrderBy(v => v.Key.Value));
        Assert.Equal(a.Reasons.Select(r => (r.Code, r.Delta, r.Value)), b.Reasons.Select(r => (r.Code, r.Delta, r.Value)));
        Assert.Equal(a.Evaluation.YieldFactor, b.Evaluation.YieldFactor);
    }

    [Fact]
    public void StepDoesNotMutateItsInput()
    {
        var env = Env();
        var start = env.InitialState();
        var before = start.Soil.Values.OrderBy(v => v.Key.Value).ToList();

        Step(env, start, Season("legumeA"));

        Assert.Equal(before, start.Soil.Values.OrderBy(v => v.Key.Value));
        Assert.Empty(start.Ledger.For(StateVarId.ResidualN));
    }
}
