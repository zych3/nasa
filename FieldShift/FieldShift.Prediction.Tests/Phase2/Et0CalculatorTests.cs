using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Tests.Support;

namespace FieldShift.Prediction.Tests.Phase2;

public class Et0CalculatorTests
{
    [Fact]
    public void Fao56Example8ExtraterrestrialRadiation()
    {
        // FAO-56 Example 8: latitude 20 degrees S, 3 September (day 246): Ra = 32.2 MJ m-2 day-1.
        var ra = Et0Calculator.ExtraterrestrialRadiation(-20, 246);

        Assert.Equal(32.2, ra, 1);
    }

    [Fact]
    public void HargreavesFollowsEquation52()
    {
        // Ra from FAO-56 Example 8 (32.2 MJ) is 13.14 mm/day. Tmax 21.5, Tmin 12.3, Tmean 16.9:
        // 0.0023 * (16.9 + 17.8) * sqrt(9.2) * 13.14 = 3.18 mm/day (worked by hand).
        var et0 = Et0Calculator.Hargreaves(-20, 246, 12.3, 21.5);

        Assert.Equal(3.18, et0, 1);
    }

    [Fact]
    public void SummerEt0IsHigherThanWinterAtPolishLatitude()
    {
        var summer = Et0Calculator.Hargreaves(52.2, 180, 12, 25);
        var winter = Et0Calculator.Hargreaves(52.2, 15, -3, 3);

        Assert.True(summer > 3 && summer < 7, $"summer ET0 {summer}");
        Assert.True(winter >= 0 && winter < 1, $"winter ET0 {winter}");
    }

    [Fact]
    public void NeverNegativeAndHandlesInvertedTemperatures()
    {
        Assert.Equal(0, Et0Calculator.Hargreaves(52, 100, 20, 10));
        Assert.True(Et0Calculator.Hargreaves(52, 10, -30, -25) >= 0);
    }

    [Fact]
    public void PolarLatitudesDoNotProduceNaN()
    {
        Assert.False(double.IsNaN(Et0Calculator.ExtraterrestrialRadiation(89, 172)));
        Assert.False(double.IsNaN(Et0Calculator.ExtraterrestrialRadiation(89, 355)));
    }

    [Fact]
    public void SuppliedEt0WinsOverTheEstimate()
    {
        var day = new DailyWeather(new DateOnly(2020, 7, 1), 12, 25, 0, Et0Mm: 9.9);

        Assert.Equal(9.9, Et0Calculator.Resolve(day, 52));
    }

    [Fact]
    public void MissingEt0IsEstimated()
    {
        var day = new DailyWeather(new DateOnly(2020, 7, 1), 12, 25, 0);

        Assert.Equal(Et0Calculator.Hargreaves(52, day.Date.DayOfYear, 12, 25), Et0Calculator.Resolve(day, 52));
    }

    [Fact]
    public void ClimateIndexFillsEt0AndCountsEstimatedDays()
    {
        var climate = new ClimateData { Years = [Weather.Constant(2020, 5, 15, 1), Weather.Constant(2021, 5, 15, 1, et0: 2)] };

        var index = new ClimateIndex(climate, 52);

        Assert.Equal(366, index.Et0EstimatedDays);
        Assert.Equal(366 + 365, index.DayCount);
        Assert.All(index.Range(new DateOnly(2020, 1, 1), new DateOnly(2021, 12, 31)), d => Assert.NotNull(d.Et0Mm));
        Assert.Equal(2, index.Range(new DateOnly(2021, 3, 1), new DateOnly(2021, 3, 1)).Single().Et0Mm);
    }

    [Fact]
    public void RangeSkipsMissingDatesAndIsOrdered()
    {
        var climate = new ClimateData { Years = [Weather.Constant(2020, 5, 15)] };
        var index = new ClimateIndex(climate, 52);

        var range = index.Range(new DateOnly(2019, 12, 30), new DateOnly(2020, 1, 3));

        Assert.Equal(3, range.Count);
        Assert.Equal(new DateOnly(2020, 1, 1), range[0].Date);
    }
}
