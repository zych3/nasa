using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Validation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase1;

public class KnowledgeBaseValidatorTests
{
    private static ValidationReport Validate(CropKnowledgeBase kb) =>
        KnowledgeBaseValidator.Validate(kb, Settings);

    private static Effect Eff(string var, EffectOp op, double amount = 1, string? when = null, string? scaleBy = null) =>
        new() { Var = new StateVarId(var), Op = op, Amount = amount, Source = "S1", When = when, ScaleBy = scaleBy };

    private static CropKnowledgeBase WithExtraEffect(Effect effect) =>
        WithCrop(Kb, "cerealA", c => c with { Effects = [.. c.Effects, effect] });

    [Fact]
    public void ValidFixturePasses()
    {
        var result = Load();

        Assert.True(result.Succeeded, result.Report.ToString());
        Assert.Empty(result.Report.Errors);
    }

    [Fact]
    public void WarnsAboutCropsWithoutPressureLoads()
    {
        var report = Validate(Kb);

        var warning = Assert.Single(report.Warnings, w => w.Code == "crop.noPressureLoads");
        Assert.Contains("catchA", warning.Where);
    }

    [Fact]
    public void WarnsAboutCropsWithoutPhResponse()
    {
        var kb = WithCrop(Kb, "cerealB", c => c with { Responses = c.Responses.Where(r => r.Var != StateVarId.Ph).ToList() });

        var report = Validate(kb);

        var warning = Assert.Single(report.Warnings, w => w.Code == "crop.noPhResponse");
        Assert.Contains("cerealB", warning.Where);
    }

    [Fact]
    public void EmitsConfidenceStatisticsForEveryCrop()
    {
        var report = Validate(Kb);

        Assert.Equal(Kb.Crops.Count, report.Count("crop.confidenceStats"));
        var cerealA = Assert.Single(report.Warnings, w => w.Code == "crop.confidenceStats" && w.Where == "crop 'cerealA'");
        Assert.Contains("high=1", cerealA.Message);
        Assert.Contains("medium=2", cerealA.Message);
    }

    [Fact]
    public void RejectsEffectOnUnregisteredVariable()
    {
        var report = Validate(WithExtraEffect(Eff("nope", EffectOp.Add)));

        Assert.True(report.HasError("effect.unknownVar"));
    }

    [Fact]
    public void RejectsResponseOnUnregisteredVariable()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with
        {
            Responses = [.. c.Responses, new Response { Var = new StateVarId("nope"), Curve = Curve.Constant(1), Target = ResponseTarget.Yield }]
        });

        Assert.True(Validate(kb).HasError("response.unknownVar"));
    }

    [Fact]
    public void RejectsLoadOnNonPressure()
    {
        var report = Validate(WithExtraEffect(Eff("humusC", EffectOp.Load)));

        Assert.True(report.HasError("effect.loadOnNonPressure"));
    }

    [Fact]
    public void RejectsSetOnPool()
    {
        var report = Validate(WithExtraEffect(Eff("residualN", EffectOp.Set)));

        Assert.True(report.HasError("effect.setOnNonEvent"));
    }

    [Fact]
    public void SetOnStockIsOnlyAWarning()
    {
        var report = Validate(WithExtraEffect(Eff("humusC", EffectOp.Set)));

        Assert.False(report.HasError("effect.setOnNonEvent"));
        Assert.True(report.HasWarning("effect.setOnStock"));
        Assert.True(report.IsValid);
    }

    [Fact]
    public void AcceptsSetOnEvent()
    {
        var report = Validate(WithExtraEffect(Eff("recentLiming", EffectOp.Set)));

        Assert.True(report.IsValid, report.ToString());
    }

    [Fact]
    public void RejectsInvalidToleranceRange()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with
        {
            Suitability = c.Suitability with { SandPct = new ToleranceRange { AbsMin = 50, OptMin = 30, OptMax = 70, AbsMax = 90 } }
        });

        Assert.True(Validate(kb).HasError("crop.toleranceRange"));
    }

    [Theory]
    [InlineData(0, 10)]
    [InlineData(100, 50)]
    [InlineData(10, 400)]
    public void RejectsInvalidSowWindow(int start, int end)
    {
        var kb = WithCrop(Kb, "cerealA", c => c with { SowWindow = new DoyWindow(start, end) });

        Assert.True(Validate(kb).HasError("crop.sowWindow"));
    }

    [Fact]
    public void RejectsInvalidHarvestWindow()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with { HarvestWindow = new DoyWindow(300, 200) });

        Assert.True(Validate(kb).HasError("crop.harvestWindow"));
    }

    [Fact]
    public void RejectsKcWithWrongLength()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with { Water = c.Water! with { Kc = [0.4, 1.1] } });

        Assert.True(Validate(kb).HasError("water.kcLength"));
    }

    [Fact]
    public void RejectsStageLengthsWithWrongLength()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with { Water = c.Water! with { StageLengthsDays = [30, 40, 60] } });

        Assert.True(Validate(kb).HasError("water.stageLength"));
    }

    [Fact]
    public void AcceptsMissingStageLengths()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with { Water = c.Water! with { StageLengthsDays = [] } });

        Assert.True(Validate(kb).IsValid);
    }

    [Fact]
    public void RejectsPressureWithoutDecay()
    {
        var kb = WithStateVariable(Kb, "pathogen:p1", v => v with { DecayPerYear = null });

        Assert.True(Validate(kb).HasError("stateVar.decayMissing"));
    }

    [Theory]
    [InlineData(-0.1)]
    [InlineData(1.5)]
    public void RejectsPressureDecayOutsideUnitInterval(double decay)
    {
        var kb = WithStateVariable(Kb, "pathogen:p1", v => v with { DecayPerYear = decay });

        Assert.True(Validate(kb).HasError("stateVar.decayRange"));
    }

    [Fact]
    public void RejectsUnknownCropInPredecessorRating()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with
        {
            PredecessorRating = c.PredecessorRating! with { BestBefore = [new CropId("ghost")] }
        });

        Assert.True(Validate(kb).HasError("predecessorRating.unknownCrop"));
    }

    [Fact]
    public void RejectsUnknownCropInHistory()
    {
        var plot = PlotWithHistory(
            new HistoricSeason { HarvestYear = 2024, Crop = new CropId("ghost") },
            new HistoricSeason { HarvestYear = 2025, Crop = new CropId("cerealA"), CatchCrop = new CropId("ghost2") });

        var report = KnowledgeBaseValidator.ValidatePlot(plot, Kb);

        Assert.Equal(2, report.Count("history.unknownCrop"));
    }

    [Fact]
    public void AcceptsKnownHistory()
    {
        var plot = PlotWithHistory(new HistoricSeason { HarvestYear = 2025, Crop = new CropId("legumeA") });

        Assert.True(KnowledgeBaseValidator.ValidatePlot(plot, Kb).IsValid);
    }

    [Fact]
    public void RejectsSelectorThatMatchesNoCrop()
    {
        var kb = WithInteractions(Kb,
        [
            new InteractionOverride
            {
                Prev = CropSelector.Parse("tag:doesNotExist"), Next = CropSelector.Parse("cerealA"),
                Delta = -0.1, Reason = "test"
            }
        ]);

        Assert.True(Validate(kb).HasError("selector.noMatch"));
    }

    [Fact]
    public void RejectsGroupShareSelectorThatMatchesNoCrop()
    {
        var settings = Settings with
        {
            Constraints = new Engine.ConstraintSettings
            {
                GroupShares = [new Engine.GroupShare { Selector = CropSelector.Parse("family:Nothing"), MaxShare = 0.5 }]
            }
        };

        var report = KnowledgeBaseValidator.Validate(Kb, settings);

        Assert.True(report.HasError("selector.noMatch"));
    }

    [Fact]
    public void RejectsSourceThatIsNotInTheCropsSources()
    {
        var kb = WithExtraEffect(Eff("humusC", EffectOp.Add) with { Source = "MISSING" });

        Assert.True(Validate(kb).HasError("source.unknown"));
    }

    [Fact]
    public void RejectsUnknownSourceInAction()
    {
        var kb = WithAction(Kb, "lime", a => a with { Effects = [Eff("humusC", EffectOp.Add) with { Source = "MISSING" }] });

        Assert.True(Validate(kb).HasError("source.unknown"));
    }

    [Fact]
    public void RejectsUnknownWhenCondition()
    {
        var report = Validate(WithExtraEffect(Eff("humusC", EffectOp.Add, when: "weather.isRaining")));

        Assert.True(report.HasError("effect.unknownCondition"));
    }

    [Theory]
    [InlineData("residue.incorporate")]
    [InlineData("residue.remove")]
    [InlineData("residue.mulch")]
    [InlineData("farmer.hasLivestockOrManure")]
    [InlineData("farmer.hasIrrigation")]
    public void AcceptsSupportedConditions(string condition)
    {
        Assert.True(Validate(WithExtraEffect(Eff("humusC", EffectOp.Add, when: condition))).IsValid);
    }

    [Fact]
    public void RejectsUnknownScaleBy()
    {
        var report = Validate(WithExtraEffect(Eff("humusC", EffectOp.Add, scaleBy: "management.weather")));

        Assert.True(report.HasError("effect.unknownScaleBy"));
    }

    [Fact]
    public void AcceptsNRateScaling()
    {
        Assert.True(Validate(WithExtraEffect(Eff("residualN", EffectOp.Add, scaleBy: "management.nRate"))).IsValid);
    }

    [Fact]
    public void RejectsStrategyWithoutWeights()
    {
        var kb = WithStrategies(Kb, [Kb.Strategies.Values.First() with { Weights = new Dictionary<Objective, double>() }]);

        Assert.True(Validate(kb).HasError("strategy.noWeights"));
    }

    [Fact]
    public void ReportsAllErrorsNotOnlyTheFirst()
    {
        var kb = WithCrop(Kb, "cerealA", c => c with
        {
            SowWindow = new DoyWindow(300, 100),
            Effects = [.. c.Effects, Eff("nope", EffectOp.Add), Eff("humusC", EffectOp.Load)]
        });

        var report = Validate(kb);

        Assert.True(report.HasError("crop.sowWindow"));
        Assert.True(report.HasError("effect.unknownVar"));
        Assert.True(report.HasError("effect.loadOnNonPressure"));
        Assert.True(report.Errors.Count() >= 3);
    }
}
