using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Calendar;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Water;
using FieldShift.Prediction.Tests.Support;
using static FieldShift.Prediction.Tests.Support.Fixture;

namespace FieldShift.Prediction.Tests.Phase2;

public class WaterBalanceTests
{
    private const int Year = 2020;

    // Flat crop: Kc 1 in every stage, 4 x 10 days, depletion fraction 0.5, root depth 1 m.
    private static Crop FlatCrop() => Kb.GetCrop(new CropId("cerealB")) with
    {
        Water = new WaterProfile
        {
            Kc = [1, 1, 1], StageLengthsDays = [10, 10, 10, 10], RootDepthM = 1.0, DepletionFraction = 0.5
        }
    };

    private static PlotFeatures Features(double awcMmPerM) => FeatureBuilder.Build(PlotWithHistory(), Settings).Features with
    {
        AwcMmPerM = awcMmPerM
    };

    private static ClimateIndex Climate(double et0, double precip) =>
        new(Weather.Years(Year - 1, 2, y => Weather.Constant(y, precip: precip, et0: et0)), 52);

    private static double Stress(Crop crop, double awc, double et0, double precip, FarmerInputs? farmer = null)
    {
        var season = SeasonCalendar.Build(crop, Year, Settings);
        return WaterBalance.Evaluate(crop, Features(awc), farmer ?? new FarmerInputs(), season, Climate(et0, precip)).StressIndex;
    }

    [Fact]
    public void NoStressWhenTotalDemandFitsInsideReadilyAvailableWater()
    {
        // 40 days x 5 mm = 200 mm demand, RAW = 0.5 * 400 = 200 mm: the crop never leaves the no-stress zone.
        Assert.Equal(0, Stress(FlatCrop(), awc: 400, et0: 5, precip: 0), 12);
    }

    [Fact]
    public void NoStressWhenRainMatchesDemand()
    {
        Assert.Equal(0, Stress(FlatCrop(), awc: 40, et0: 5, precip: 5), 12);
    }

    [Fact]
    public void StressRisesAsSoilHoldsLessWater()
    {
        var big = Stress(FlatCrop(), awc: 300, et0: 5, precip: 0);
        var small = Stress(FlatCrop(), awc: 100, et0: 5, precip: 0);
        var tiny = Stress(FlatCrop(), awc: 40, et0: 5, precip: 0);

        Assert.True(big < small && small < tiny, $"{big} {small} {tiny}");
        Assert.InRange(tiny, 0, 1);
    }

    [Fact]
    public void StressRisesAsRainfallDrops()
    {
        var wet = Stress(FlatCrop(), awc: 100, et0: 5, precip: 3);
        var dry = Stress(FlatCrop(), awc: 100, et0: 5, precip: 0);

        Assert.True(wet < dry);
    }

    [Fact]
    public void StressIsBetweenZeroAndOneEvenInExtremeDrought()
    {
        var stress = Stress(FlatCrop(), awc: 20, et0: 12, precip: 0);

        Assert.InRange(stress, 0.5, 1.0);
    }

    [Fact]
    public void StressIsHandCheckableForAConstantDemand()
    {
        // TAW = 100 mm, RAW = 50 mm, ET = 5 mm/day for 40 days, no rain.
        // Depletion at the start of day k is 5(k-1) until it exceeds RAW; from then on
        // Ks = (TAW - Dr) / (TAW - RAW). Reference value from an independent spreadsheet-style loop.
        double dr = 0, actual = 0, demand = 0;
        for (var day = 1; day <= 40; day++)
        {
            var ks = dr <= 50 ? 1.0 : (100 - dr) / 50.0;
            var weight = day is >= 21 and <= 30 ? 2.0 : 1.0;
            actual += weight * ks * 5;
            demand += weight * 5;
            dr = Math.Min(100, dr + ks * 5);
        }
        var expected = 1 - actual / demand;

        Assert.Equal(expected, Stress(FlatCrop(), awc: 100, et0: 5, precip: 0), 9);
        Assert.InRange(expected, 0.4, 0.7);
    }

    [Fact]
    public void DroughtInTheMidStageCountsDoubleComparedWithTheLateStage()
    {
        var crop = FlatCrop();
        var season = SeasonCalendar.Build(crop, Year, Settings);

        double Run(DateOnly dryFrom, DateOnly dryTo)
        {
            var climate = new ClimateIndex(Weather.Years(Year - 1, 2, y => Weather.Custom(y, d =>
                new DailyWeather(d, 5, 15, d >= dryFrom && d <= dryTo ? 0 : 50, 5))), 52);
            return WaterBalance.Evaluate(crop, Features(10), new FarmerInputs(), season, climate).StressIndex;
        }

        var mid = Run(season.StageStart(GrowthStage.Mid), season.StageEnds[2]);
        var late = Run(season.StageStart(GrowthStage.Late), season.StageEnds[3]);

        Assert.True(mid > late, $"mid {mid} late {late}");
    }

    [Fact]
    public void IrrigationSetsStressToZeroWithAReason()
    {
        var crop = FlatCrop();
        var season = SeasonCalendar.Build(crop, Year, Settings);

        var result = WaterBalance.Evaluate(crop, Features(20), new FarmerInputs { HasIrrigation = true }, season, Climate(8, 0));

        Assert.Equal(0, result.StressIndex);
        Assert.Equal(WaterMethod.Irrigated, result.Method);
        Assert.Contains(result.Reasons, r => r.Code == "water.irrigated");
    }

    [Fact]
    public void WithoutWaterProfileFallsBackToSeasonalRainfall()
    {
        var crop = Kb.GetCrop(new CropId("cerealB")) with { Water = null };
        var season = SeasonCalendar.Build(crop, Year, Settings);
        var days = season.End.DayNumber - season.Sow.DayNumber + 1;

        var result = WaterBalance.Evaluate(crop, Features(100), new FarmerInputs(), season, Climate(3, 1));

        Assert.Equal(WaterMethod.PrecipitationFallback, result.Method);
        Assert.Equal((350.0 - days) / 350.0, result.StressIndex, 9);
        Assert.Contains(result.Reasons, r => r.Code == "water.seasonalRainfall");
    }

    [Fact]
    public void FallbackHasNoStressWhenRainMeetsTheNeed()
    {
        var crop = Kb.GetCrop(new CropId("cerealB")) with { Water = null };
        var season = SeasonCalendar.Build(crop, Year, Settings);

        var result = WaterBalance.Evaluate(crop, Features(100), new FarmerInputs(), season, Climate(3, 10));

        Assert.Equal(0, result.StressIndex);
    }

    [Fact]
    public void MissingStageLengthsFallBackAndSayWhy()
    {
        var crop = FlatCrop() with { Water = FlatCrop().Water! with { StageLengthsDays = [] } };
        var season = SeasonCalendar.Build(crop, Year, Settings);

        var result = WaterBalance.Evaluate(crop, Features(100), new FarmerInputs(), season, Climate(3, 0));

        Assert.Equal(WaterMethod.PrecipitationFallback, result.Method);
        Assert.Contains(result.Reasons, r => r.Code == "water.noStageLengths");
    }

    [Fact]
    public void NoWaterInformationAtAllIsReportedNotInvented()
    {
        var crop = Kb.GetCrop(new CropId("cerealB")) with
        {
            Water = null,
            Suitability = Kb.GetCrop(new CropId("cerealB")).Suitability with { SeasonWaterNeedMm = null }
        };
        var season = SeasonCalendar.Build(crop, Year, Settings);

        var result = WaterBalance.Evaluate(crop, Features(100), new FarmerInputs(), season, Climate(3, 0));

        Assert.Equal(WaterMethod.NoData, result.Method);
        Assert.Contains(result.Reasons, r => r.Code == "water.noData");
    }

    [Fact]
    public void KcRampsLinearlyAcrossDevelopmentAndLateStages()
    {
        var ramp = FlatCrop() with { Water = FlatCrop().Water! with { Kc = [0.2, 1.4, 1.0] } };
        var flatLow = FlatCrop() with { Water = FlatCrop().Water! with { Kc = [0.2, 0.2, 0.2] } };

        Assert.True(Stress(ramp, 100, 5, 0) > Stress(flatLow, 100, 5, 0));
    }
}
