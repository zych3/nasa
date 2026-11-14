using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;
using static FieldShift.Prediction.Tests.Support.Sim;

namespace FieldShift.Prediction.Tests.Phase4;

public class HistorySeederTests
{
    private static HistoricSeason Past(int year, string crop, string? catchCrop = null, double certainty = 1.0,
        ResidueHandling? residue = null, params string[] actions) => new()
    {
        HarvestYear = year,
        Crop = new CropId(crop),
        CatchCrop = catchCrop is null ? null : new CropId(catchCrop),
        Certainty = certainty,
        Residue = residue,
        Actions = actions.Select(a => new ActionId(a)).ToList()
    };

    private static SeededHistory Seed(SimEnvironment env, params HistoricSeason[] history) =>
        HistorySeeder.Seed(PlotWithHistory(history), env);

    [Fact]
    public void NoHistoryStartsNeutralWithAWarning()
    {
        var env = Env(withSurvival: false);

        var seeded = Seed(env);

        Assert.Equal(5.75, V(seeded.State.Soil, "ph"));
        Assert.Equal(15.3 * 1.4 * 0.3 * 10_000, V(seeded.State.Soil, "humusC"), 6);
        Assert.Equal(0, V(seeded.State.Soil, "residualN"));
        Assert.Null(seeded.State.PreviousMainCrop);
        Assert.Contains(seeded.Warnings, w => w.Code == "history.none");
    }

    [Fact]
    public void LegumeInTheLastHistorySeasonRaisesResidualNForTheFirstPlanSeason()
    {
        var env = Env();
        var seeded = Seed(env, Past(2025, "legumeA"));

        var first = Step(env, seeded.State, Season("cerealA"), 0);

        Assert.Equal(40, V(first.Evaluation.StateBefore, "residualN"));
        Assert.Empty(seeded.Warnings);
    }

    [Fact]
    public void HistorySeasonsHaveNegativeIndicesAndShowUpAsCauses()
    {
        var env = Env();
        var seeded = Seed(env, Past(2024, "cerealA"), Past(2025, "cerealB"));

        // p1: cerealA (-2) loads 0.5, which decays to 0.2; cerealB (-1) then loads 0.2. A tie goes to the earlier season.
        var causes = seeded.State.Ledger.Top(new StateVarId("pathogen:p1"), 3);

        Assert.Equal([new Cause(-2, new CropId("cerealA")), new Cause(-1, new CropId("cerealB"))], causes);
        Assert.Equal(0.5 * 0.4 + 0.2, V(seeded.State.Soil, "pathogen:p1"), 9);
    }

    [Fact]
    public void ImmediateHistoryIsUsedForCropToCropOverrides()
    {
        var env = Env();
        var seeded = Seed(env, Past(2025, "cerealB"));

        var first = Step(env, seeded.State, Season("cerealA"), 0);

        var o = Assert.Single(first.Reasons, r => r.Kind == ReasonKind.InteractionOverride);
        Assert.Equal([new Cause(-1, new CropId("cerealB"))], o.CausedBy);
        Assert.Equal(new CropId("cerealB"), seeded.State.PreviousMainCrop);
    }

    [Fact]
    public void CertaintyScalesTheSeasonsEffects()
    {
        var env = Env();

        var seeded = Seed(env, Past(2025, "legumeA", certainty: 0.5));

        Assert.Equal(20, V(seeded.State.Soil, "residualN"), 9);
        Assert.Equal(0.25, V(seeded.State.Soil, "pathogen:p2"), 9);
    }

    [Fact]
    public void HistoryIsReplayedOldestFirstWhateverTheInputOrder()
    {
        var env = Env();

        var newestLast = Seed(env, Past(2024, "cerealA"), Past(2025, "legumeA"));
        var unsorted = Seed(env, Past(2025, "legumeA"), Past(2024, "cerealA"));

        Assert.Equal(40, V(newestLast.State.Soil, "residualN"));       // legume last: N available
        Assert.Equal(40, V(unsorted.State.Soil, "residualN"));
        Assert.Equal(new CropId("legumeA"), unsorted.State.PreviousMainCrop);
    }

    [Fact]
    public void UnknownHistoryCropIsSkippedWithAWarning()
    {
        var env = Env();

        var seeded = Seed(env, Past(2024, "legumeA"), Past(2025, "ghost"));

        var w = Assert.Single(seeded.Warnings, x => x.Code == "history.unknownCrop");
        Assert.Equal(new CropId("ghost"), w.Crop);
        Assert.Equal(40, V(seeded.State.Soil, "residualN"));              // the legume season still counted
        Assert.Equal(new CropId("legumeA"), seeded.State.PreviousMainCrop);
    }

    [Fact]
    public void UnknownCatchCropIsIgnoredButTheSeasonStays()
    {
        var env = Env();

        var seeded = Seed(env, Past(2025, "legumeA", catchCrop: "ghost"));

        Assert.Contains(seeded.Warnings, w => w.Code == "history.unknownCatchCrop");
        Assert.Equal(40, V(seeded.State.Soil, "residualN"));
    }

    [Fact]
    public void RecordedCatchCropAddsItsEffects()
    {
        var env = Env();

        var seeded = Seed(env, Past(2025, "cerealB", catchCrop: "catchA"));

        Assert.Equal(15.3 * 1.4 * 0.3 * 10_000 + 40 + 60, V(seeded.State.Soil, "humusC"), 6);
        Assert.Equal(0.7, V(seeded.State.Soil, "soilCoverWinter"), 9);
    }

    [Fact]
    public void RecordedActionsAreAppliedAndUnknownOnesWarn()
    {
        var env = Env();

        var seeded = Seed(env, Past(2025, "cerealB", actions: ["lime", "ghost"]));

        Assert.Equal(1, V(seeded.State.Soil, "recentLiming"));
        Assert.Contains(seeded.Warnings, w => w.Code == "history.unknownAction");
    }

    [Theory]
    [InlineData(null, true)]                          // rootCropA's default is remove
    [InlineData(ResidueHandling.Remove, true)]
    [InlineData(ResidueHandling.Incorporate, false)]
    public void NullResidueMeansTheCropDefault(ResidueHandling? recorded, bool conditionHolds)
    {
        var kb = WithCrop(Kb, "rootCropA", c => c with
        {
            Effects = [.. c.Effects, Eff("humusC", EffectOp.Add, 7, when: "residue.remove")]
        });
        var env = Env(kb, withSurvival: false);

        var seeded = Seed(env, Past(2025, "rootCropA", residue: recorded));

        Assert.Equal(15.3 * 1.4 * 0.3 * 10_000 - 400 + (conditionHolds ? 7 : 0), V(seeded.State.Soil, "humusC"), 6);
    }

    [Fact]
    public void SeedingNeedsNoStaticSurvival()
    {
        var env = Env(withSurvival: false);

        var seeded = Seed(env, Past(2023, "cerealA"), Past(2024, "legumeA"), Past(2025, "cerealB"));

        Assert.Equal(new CropId("cerealB"), seeded.State.PreviousMainCrop);
    }

    [Fact]
    public void SeedingIsDeterministic()
    {
        var env = Env();
        var history = new[] { Past(2023, "cerealA"), Past(2024, "legumeA", "catchA"), Past(2025, "oilseedA", certainty: 0.7) };

        var a = Seed(env, history);
        var b = Seed(env, history);

        Assert.Equal(a.State.Soil.Values.OrderBy(v => v.Key.Value), b.State.Soil.Values.OrderBy(v => v.Key.Value));
    }
}
