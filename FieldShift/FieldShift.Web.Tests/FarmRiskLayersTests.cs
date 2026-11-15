using FieldShift.Web.FieldProfile;
using FieldShift.Web.MapLayers;

namespace TestProject1;

/// <summary>Plant stress parts, fungal-weather days, pest degree-days and the NASA data cache format.</summary>
public sealed class FarmRiskLayersTests
{
    private static readonly YearMonth June = new(2025, 6);

    /// <summary>Daily data for June 2025 with the same values every day.</summary>
    private static NasaPowerDailyData June2025(double t2m, double rh, double rainMm)
    {
        var days = Enumerable.Range(1, 30).Select(d => new DateOnly(2025, 6, d)).ToList();
        IReadOnlyDictionary<DateOnly, double> Same(double v) => days.ToDictionary(d => d, _ => v);
        return new NasaPowerDailyData(new Dictionary<string, IReadOnlyDictionary<DateOnly, double>>
        {
            ["T2M"] = Same(t2m),
            ["RH2M"] = Same(rh),
            ["PRECTOTCORR"] = Same(rainMm),
        });
    }

    [Fact]
    public void PlantStressParts_AddUpToTheScore()
    {
        var (drought, heat) = DerivedIndices.PlantStressParts(0.35, 5);

        Assert.Equal(36, drought, 6); // 60 × (0.50 − 0.35) / 0.25
        Assert.Equal(20, heat, 6);    // 40 × 5 / 10
        Assert.Equal(56, DerivedIndices.PlantStress(0.35, 5));
    }

    [Theory]
    [InlineData(18, 90, 0, 30)]   // mild and very humid: every day
    [InlineData(18, 78, 2, 30)]   // humid with rain: every day
    [InlineData(18, 78, 0, 0)]    // humid, no rain: none
    [InlineData(30, 95, 5, 0)]    // too hot for the rule
    [InlineData(5, 95, 5, 0)]     // too cold
    public void FungalDays_FollowTheWeatherRule(double t2m, double rh, double rain, double expected)
    {
        var climate = MonthlyAggregator.Aggregate(June2025(t2m, rh, rain), June, June);

        Assert.Equal(expected, climate.FungalDays[0]);
    }

    [Fact]
    public void FungalDays_UnknownWithoutHumidity()
    {
        var data = new NasaPowerDailyData(new Dictionary<string, IReadOnlyDictionary<DateOnly, double>>
        {
            ["T2M"] = new Dictionary<DateOnly, double> { [new DateOnly(2025, 6, 1)] = 15 },
        });

        Assert.Null(MonthlyAggregator.Aggregate(data, June, June).FungalDays[0]);
    }

    [Fact]
    public void DegreeDays_AreWarmthAboveTenDegrees()
    {
        var climate = MonthlyAggregator.Aggregate(June2025(16, 60, 0), June, June);

        Assert.Equal(180, climate.DegreeDays[0]); // 30 days × (16 − 10)
    }

    [Fact]
    public void CumulativeDegreeDays_RestartEachJanuary_AndStartUnknownMidYear()
    {
        var months = YearMonth.Range(new YearMonth(2024, 11), new YearMonth(2025, 3));
        double?[] monthly = [5, 0, 10, 20, null];

        var sums = DerivedIndices.CumulativeDegreeDays(months, monthly);

        // Nov–Dec 2024: the year's start is missing; Jan 2025 restarts; a gap leaves the rest unknown.
        Assert.Equal([null, null, 10, 30, null], sums);
    }

    [Fact]
    public void NasaCache_RoundTripsDailyData()
    {
        var data = June2025(18, 90, 1.5);

        var back = NasaDailyCache.Deserialize(NasaDailyCache.Serialize(data));

        Assert.NotNull(back);
        Assert.Equal(data.Parameters["RH2M"], back!.Parameters["RH2M"]);
        Assert.Null(NasaDailyCache.Deserialize("not json"));
    }

    [Fact]
    public void NasaCache_KeyIgnoresParameterOrder()
    {
        var from = new DateOnly(2025, 1, 1);
        var to = new DateOnly(2025, 12, 31);

        Assert.Equal(
            NasaDailyCache.Key(52.2, 21.48, from, to, ["T2M", "RH2M"]),
            NasaDailyCache.Key(52.2, 21.48, from, to, ["RH2M", "T2M"]));
    }
}
