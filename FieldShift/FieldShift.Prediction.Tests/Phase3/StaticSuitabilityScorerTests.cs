using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Survival;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase3;

public class StaticSuitabilityScorerTests
{
    private static Crop Crop(string id) => Kb.GetCrop(new CropId(id));

    private static PlotFeatures Features => FeatureBuilder.Build(PlotWithHistory(), Settings).Features;

    private static CropStaticSurvival Score(
        string crop, ClimateData climate, FarmerInputs? farmer = null, EngineSettings? settings = null) =>
        StaticSuitabilityScorer.Score(Crop(crop), Features, new ClimateIndex(climate, 52.2),
            farmer ?? new FarmerInputs(), settings ?? Settings);

    private static ClimateData Mild(int years = 25) =>
        Weather.Years(2000, years, y => Weather.Constant(y, tMin: 5, tMax: 15, precip: 3, et0: 1, snowCm: 0));

    private static EngineSettings Geometric() =>
        Settings with { Survival = Settings.Survival with { Aggregator = FactorAggregation.GeometricMean } };

    [Fact]
    public void TextureIsTheMinimumOfSandAndClayScores()
    {
        // cerealB, sand 77.5 % (optMax 75, absMax 90) -> 0.8333; clay 9 % (absMin 3, optMin 10) -> 0.8571
        var year = Score("cerealB", Mild()).Years[0];

        Assert.Equal(12.5 / 15.0, year.Factors.Texture!.Value, 9);
    }

    [Fact]
    public void TextureUsesGeometricMeanWhenConfigured()
    {
        var year = Score("cerealB", Mild(), settings: Geometric()).Years[0];

        Assert.Equal(Math.Sqrt(12.5 / 15.0 * 6.0 / 7.0), year.Factors.Texture!.Value, 9);
    }

    [Fact]
    public void TextureIsConstantAcrossYears()
    {
        var years = Score("cerealB", Mild()).Years;

        Assert.All(years, y => Assert.Equal(years[0].Factors.Texture, y.Factors.Texture));
    }

    [Fact]
    public void CropWithoutTextureRangesHasNoTextureFactor()
    {
        var crop = Crop("cerealB") with { Suitability = Crop("cerealB").Suitability with { SandPct = null, ClayPct = null } };

        var s = StaticSuitabilityScorer.Score(crop, Features, new ClimateIndex(Mild(), 52.2), new FarmerInputs(), Settings);

        Assert.Null(s.Years[0].Factors.Texture);
    }

    [Fact]
    public void HeatCountsHotDaysInsideTheFloweringWindowOnly()
    {
        // cerealB flowers on days 142..196 of the year (sow 87 + 55 .. + 109). Hot only on days 142..145: 4 days.
        var climate = Weather.Years(2000, 3, y => Weather.Custom(y, d =>
            new DailyWeather(d, 10, d.DayOfYear is >= 142 and <= 145 or (>= 10 and <= 20) ? 35 : 20, 3, 1, 0)));

        var year = Score("cerealB", climate).Years[1];

        Assert.Equal(4, year.Factors.HeatDays);
        Assert.Equal(4.0 / 6.0, year.Factors.Heat!.Value, 9);
    }

    [Fact]
    public void NoHotDaysMeansFullHeatScore()
    {
        Assert.All(Score("cerealB", Mild()).Years, y => Assert.Equal(1.0, y.Factors.Heat));
    }

    [Fact]
    public void ConstantHeatKillsTheHeatFactor()
    {
        var climate = Weather.Years(2000, 3, y => Weather.Constant(y, 20, 36, 3, 1, 0));

        Assert.All(Score("cerealB", climate).Years, y => Assert.Equal(0.0, y.Factors.Heat));
    }

    [Fact]
    public void CatchCropsHaveNoHeatFactor()
    {
        var climate = Weather.Years(2000, 3, y => Weather.Constant(y, 20, 36, 3, 1, 0));

        Assert.All(Score("catchA", climate).Years, y => Assert.Null(y.Factors.Heat));
    }

    private static ClimateData WithColdDay(DateOnly day, double tMin, double? snow, int years = 5) =>
        Weather.Years(2005, years, y => Weather.Custom(y, d =>
            new DailyWeather(d, d == day ? tMin : 2, d == day ? tMin + 5 : 12, 3, 1, snow)));

    [Fact]
    public void BitterColdWithoutSnowKillsAWinterCrop()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2008, 1, 15), -25, 0));

        Assert.Equal(0.0, s.ScoreIn(2008));
        Assert.Equal(1.0, s.Years.Single(y => y.HarvestYear == 2007).Factors.Winterkill);
    }

    [Fact]
    public void SnowCoverProtectsDownToTheWithSnowLimit()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2008, 1, 15), -25, 10));

        Assert.Equal(1.0, s.Years.Single(y => y.HarvestYear == 2008).Factors.Winterkill);
    }

    [Fact]
    public void ColdBeyondTheWithSnowLimitKillsEvenUnderSnow()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2008, 1, 15), -30, 10));

        Assert.Equal(0.0, s.Years.Single(y => y.HarvestYear == 2008).Factors.Winterkill);
    }

    [Fact]
    public void ThinSnowBelowTheProtectiveDepthDoesNotProtect()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2008, 1, 15), -22, 3));

        Assert.Equal(0.0, s.Years.Single(y => y.HarvestYear == 2008).Factors.Winterkill);
    }

    [Fact]
    public void FrostAfterTheEndOfMarchIsIgnored()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2008, 4, 10), -25, 0));

        Assert.Equal(1.0, s.Years.Single(y => y.HarvestYear == 2008).Factors.Winterkill);
    }

    [Fact]
    public void FrostBeforeSowingIsIgnored()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2007, 9, 5), -25, 0));

        Assert.Equal(1.0, s.Years.Single(y => y.HarvestYear == 2008).Factors.Winterkill);
    }

    [Fact]
    public void MissingSnowDataAssumesNoSnowAndWarns()
    {
        var s = Score("cerealA", WithColdDay(new DateOnly(2008, 1, 15), -25, snow: null));

        Assert.Equal(0.0, s.ScoreIn(2008));
        Assert.Contains(s.Reasons, r => r.Code == "winterkill.noSnowData");
    }

    [Fact]
    public void SpringCropsAreNotScoredOnWinterkill()
    {
        var s = Score("cerealB", WithColdDay(new DateOnly(2008, 1, 15), -40, 0));

        Assert.All(s.Years, y => Assert.Null(y.Factors.Winterkill));
    }

    [Fact]
    public void WinterCropsGet24Of25YearsWithAReason()
    {
        var s = Score("cerealA", Mild());

        Assert.Equal(24, s.Years.Count);
        Assert.Contains(s.Reasons, r => r.Code == "calendar.seasonsEvaluated");
        Assert.Equal(25, Score("cerealB", Mild()).Years.Count);
    }

    [Fact]
    public void IrrigationGivesFullWaterScore()
    {
        var drought = Weather.Years(2000, 3, y => Weather.Constant(y, 5, 15, 0, 6, 0));

        var s = Score("cerealB", drought, new FarmerInputs { HasIrrigation = true });

        Assert.All(s.Years, y => Assert.Equal(1.0, y.Factors.Water));
    }

    [Fact]
    public void DroughtLowersTheWaterFactorViaTheConfiguredCurve()
    {
        var drought = Weather.Years(2000, 3, y => Weather.Constant(y, 5, 15, 0, 6, 0));

        var year = Score("cerealB", drought).Years[0];

        Assert.True(year.Factors.WaterStress > 0.5);
        Assert.Equal(Settings.Survival.WaterStressToScore.Evaluate(year.Factors.WaterStress), year.Factors.Water!.Value, 12);
    }

    [Fact]
    public void ScoreIsTheMinimumOfTheFactors()
    {
        var climate = Weather.Years(2000, 3, y => Weather.Constant(y, 5, 36, 0, 6, 0));

        var year = Score("cerealB", climate).Years[0];

        Assert.Equal(year.Factors.Applicable.Min(), year.Score, 12);
        Assert.Equal(0.0, year.Score);
    }

    [Fact]
    public void GeometricMeanCombinesFactorsMultiplicatively()
    {
        var year = Score("cerealB", Mild(), settings: Geometric()).Years[0];
        var f = year.Factors.Applicable.ToList();

        Assert.Equal(Math.Exp(f.Average(Math.Log)), year.Score, 12);
    }

    [Fact]
    public void NoClimateGivesAZeroScoreAndAReason()
    {
        var s = Score("cerealB", new ClimateData { Years = [] });

        Assert.Empty(s.Years);
        Assert.Equal(0, s.Cvar);
        Assert.Contains(s.Reasons, r => r.Code == "screening.noClimate");
    }

    [Fact]
    public void MeanAndCvarSummariseTheYears()
    {
        var climate = Weather.Years(2001, 4, y => Weather.Custom(y, d =>
            new DailyWeather(d, 10, y == 2003 ? 36 : 20, 3, 1, 0)));

        var s = Score("cerealB", climate);

        var scores = s.Years.Select(y => y.Score).ToList();
        Assert.Equal(scores.Average(), s.Mean, 12);
        Assert.Equal(scores.Min(), s.Cvar, 12);        // ceil(0.2 * 4) = 1 worst year
        Assert.Equal(0.0, s.ScoreIn(2003));
    }
}

public class SurvivalAggregatorTests
{
    [Fact]
    public void CvarIsTheMeanOfTheWorstCeilFractionTimesN()
    {
        var values = Enumerable.Range(1, 10).Select(i => i / 10.0).ToList();

        Assert.Equal(0.15, SurvivalAggregator.Cvar(values, 0.2), 12);
    }

    [Theory]
    [InlineData(25, 5)]
    [InlineData(24, 5)]
    [InlineData(4, 1)]
    [InlineData(1, 1)]
    public void CvarTakesCeilingOfFractionTimesCount(int n, int worstCount)
    {
        var values = Enumerable.Range(1, n).Select(i => (double)i).ToList();

        Assert.Equal(Enumerable.Range(1, worstCount).Average(), SurvivalAggregator.Cvar(values, 0.2), 12);
    }

    [Fact]
    public void CvarOfNothingIsZero() => Assert.Equal(0, SurvivalAggregator.Cvar([], 0.2));

    [Fact]
    public void CombineHandlesEdgeCases()
    {
        Assert.Equal(1.0, SurvivalAggregator.Combine([], FactorAggregation.Min));
        Assert.Equal(0.0, SurvivalAggregator.Combine([0.0, 1.0], FactorAggregation.GeometricMean));
        Assert.Equal(0.5, SurvivalAggregator.Combine([0.5, 0.9], FactorAggregation.Min));
        Assert.Equal(Math.Sqrt(0.5 * 0.8), SurvivalAggregator.Combine([0.5, 0.8], FactorAggregation.GeometricMean), 12);
    }
}
