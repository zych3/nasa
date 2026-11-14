using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Survival;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase3;

public class CropScreenerTests
{
    private static ClimateData Mild() =>
        Weather.Years(2000, 25, y => Weather.Constant(y, tMin: 5, tMax: 15, precip: 3, et0: 1, snowCm: 0));

    private static ClimateData Dry() =>
        Weather.Years(2000, 25, y => Weather.Constant(y, tMin: 5, tMax: 15, precip: 0, et0: 5, snowCm: 0));

    private static ScreeningOutcome Screen(
        ClimateData climate, FarmerInputs? farmer = null, CropKnowledgeBase? kb = null, EngineSettings? settings = null)
    {
        kb ??= Kb;
        settings ??= Settings;
        var plot = PlotWithHistory() with { Climate = climate, Farmer = farmer ?? new FarmerInputs() };
        var features = FeatureBuilder.Build(plot, settings).Features;
        return CropScreener.Screen(kb, features, new ClimateIndex(climate, plot.Location.Lat), plot.Farmer,
            settings, kb.Strategies.Values.ToList());
    }

    private static CropKnowledgeBase WithKc(CropKnowledgeBase kb, string crop, double kc) =>
        WithCrop(kb, crop, c => c with { Water = c.Water! with { Kc = [kc, kc, kc] } });

    [Fact]
    public void EveryCropInAMildClimateIsACandidate()
    {
        var outcome = Screen(Mild());

        Assert.Equal(Kb.Crops.Count, outcome.Results.Count);
        Assert.All(outcome.Results, r => Assert.True(r.IsCandidate, $"{r.Crop}: cvar {r.SurvivalCvar:F2}"));
    }

    [Fact]
    public void ResultsAreOrderedByCropIdOrdinal()
    {
        var ids = Screen(Mild()).Results.Select(r => r.Crop.Value).ToList();

        Assert.Equal(ids.Order(StringComparer.Ordinal).ToList(), ids);
    }

    [Fact]
    public void FarmerExclusionRemovesTheCropWithAReason()
    {
        var outcome = Screen(Mild(), new FarmerInputs { ExcludedCrops = [new CropId("rootCropA")] });

        var result = outcome[new CropId("rootCropA")];
        Assert.False(result.IsCandidate);
        Assert.True(result.ExcludedByFarmer);
        Assert.Contains(result.Reasons, r => r.Code == "screening.excluded.farmer");
        Assert.Equal(Kb.Crops.Count - 1, outcome.Candidates.Count());
    }

    [Fact]
    public void DryClimateScreensOutHighKcCropsWithAWaterReason()
    {
        var kb = WithKc(WithKc(Kb, "cerealB", 1.3), "legumeA", 0.1);

        var outcome = Screen(Dry(), kb: kb);

        var thirsty = outcome[new CropId("cerealB")];
        Assert.False(thirsty.IsCandidate);
        Assert.Equal("water", thirsty.LimitingFactor);
        Assert.Contains(thirsty.Reasons, r => r.Code == "screening.limitingFactor.water");
        var excluded = Assert.Single(thirsty.Reasons, r => r.Code == "screening.excluded.survivalFloor");
        Assert.Contains("water", excluded.Message);

        var frugal = outcome[new CropId("legumeA")];
        Assert.True(frugal.IsCandidate, $"legumeA cvar {frugal.SurvivalCvar:F2}");
    }

    [Fact]
    public void IrrigationRescuesThirstyCrops()
    {
        var kb = WithKc(Kb, "cerealB", 1.3);

        var outcome = Screen(Dry(), new FarmerInputs { HasIrrigation = true }, kb);

        Assert.True(outcome[new CropId("cerealB")].IsCandidate);
    }

    [Fact]
    public void CandidateThresholdIsTheLowestFloorAmongTheRequestedStrategies()
    {
        var kb = WithKc(Kb, "cerealB", 1.3);
        var plot = PlotWithHistory() with { Climate = Dry() };
        var features = FeatureBuilder.Build(plot, Settings).Features;
        var climate = new ClimateIndex(plot.Climate, plot.Location.Lat);

        var strict = CropScreener.Screen(kb, features, climate, plot.Farmer, Settings, [kb.Strategies[new StrategyId("survival")]]);
        var lenient = CropScreener.Screen(kb, features, climate, plot.Farmer, Settings, [kb.Strategies[new StrategyId("soilHealth")]]);
        var both = CropScreener.Screen(kb, features, climate, plot.Farmer, Settings, kb.Strategies.Values.ToList());

        Assert.Equal(0.5, strict.Results[0].Floor);
        Assert.Equal(0.3, both.Results[0].Floor);
        Assert.True(lenient.Candidates.Count() >= strict.Candidates.Count());
        Assert.Equal(lenient.Candidates.Select(c => c.Crop), both.Candidates.Select(c => c.Crop));
    }

    [Fact]
    public void NeedsAtLeastOneStrategy()
    {
        var plot = PlotWithHistory() with { Climate = Mild() };
        var features = FeatureBuilder.Build(plot, Settings).Features;

        Assert.Throws<ArgumentException>(() =>
            CropScreener.Screen(Kb, features, new ClimateIndex(plot.Climate, 52), plot.Farmer, Settings, []));
    }

    [Fact]
    public void ResultExposesTheFactorBreakdownAndWorstYears()
    {
        var climate = Weather.Years(2000, 25, y => Weather.Custom(y, d =>
            new DailyWeather(d, 10, y < 2010 ? 36 : 20, 3, 1, 0)));

        var result = Screen(climate)[new CropId("cerealB")];

        Assert.Equal(25, result.Years.Count);
        Assert.Equal(5, result.WorstYears.Count);              // ceil(0.2 * 25)
        Assert.All(result.WorstYears, y => Assert.True(y < 2010));
        Assert.Equal("heat", result.LimitingFactor);
        Assert.All(result.Years, y => Assert.NotNull(y.Factors.Texture));
    }

    [Fact]
    public void WarningsCarryDataGaps()
    {
        var noSnow = Weather.Years(2000, 25, y => Weather.Constant(y, 5, 15, 3));

        var outcome = Screen(noSnow);

        Assert.Contains(outcome.Warnings, w => w.Code == "winterkill.noSnowData");
        Assert.Contains(outcome.Warnings, w => w.Code == "climate.et0Estimated");
        Assert.Contains(outcome.Warnings, w => w.Code == "calendar.seasonsEvaluated");
    }

    [Fact]
    public void StaticSurvivalTableIsCachedPerCropAndYear()
    {
        var outcome = Screen(Mild());

        var table = outcome.Survival;
        Assert.Equal(Kb.Crops.Count, table.All.Count());
        Assert.NotNull(table[new CropId("cerealB")].ScoreIn(2010));
        Assert.Null(table[new CropId("cerealA")].ScoreIn(2000));
    }

    [Fact]
    public void ScreeningIsDeterministic()
    {
        var a = Screen(Dry());
        var b = Screen(Dry());

        Assert.Equal(
            a.Results.Select(r => (r.Crop, r.IsCandidate, r.SurvivalMean, r.SurvivalCvar)),
            b.Results.Select(r => (r.Crop, r.IsCandidate, r.SurvivalMean, r.SurvivalCvar)));
    }
}
