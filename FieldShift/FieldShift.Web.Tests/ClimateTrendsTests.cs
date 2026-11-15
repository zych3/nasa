using FieldShift.Web.ClimateTrends;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;

namespace TestProject1;

public class ClimateTrendsTests
{
    private const double Lat = 52.2;

    /// <summary>A mild, wet day: no frost, no heat, no dry spell.</summary>
    private static readonly WeatherDay Mild = new(TMin: 5, TMax: 15, TMean: 10, Precipitation: 2);

    /// <summary>Every day of the years is <see cref="Mild"/>, then <paramref name="change"/> may replace days.</summary>
    private static Dictionary<DateOnly, WeatherDay> Days(int fromYear, int toYear, Func<DateOnly, WeatherDay?>? change = null)
    {
        var days = new Dictionary<DateOnly, WeatherDay>();
        for (var d = new DateOnly(fromYear, 1, 1); d.Year <= toYear; d = d.AddDays(1))
            days[d] = change?.Invoke(d) ?? Mild;
        return days;
    }

    private static YearWeather Year(int year, Func<DateOnly, WeatherDay?>? change = null) =>
        new(year, Lat, Days(year, year, change));

    // ---------- statistics ----------

    [Fact]
    public void ASteadyRiseIsACertainTrendWithTheExactSlope()
    {
        var years = Enumerable.Range(2001, 10).ToList();
        var result = TrendStatistics.Analyze(years, years.Select(y => 3.0 + 0.5 * (y - 2001)).ToList())!.Value;

        Assert.Equal(0.5, result.SlopePerYear, 9);
        // S = 45, variance = 125, z = 44 / sqrt(125) = 3.935 -> p = 0.000083
        Assert.Equal(0.000083, result.PValue, 5);
    }

    [Fact]
    public void AFlatSeriesHasNoTrend()
    {
        var result = TrendStatistics.Analyze([2001, 2002, 2003, 2004], [7, 7, 7, 7])!.Value;

        Assert.Equal(0, result.SlopePerYear);
        Assert.Equal(1, result.PValue);
    }

    [Fact]
    public void OneOddYearDoesNotMakeATrend()
    {
        var years = Enumerable.Range(2001, 20).ToList();
        var values = years.Select(y => y == 2020 ? 100.0 : y % 2).ToList();

        var result = TrendStatistics.Analyze(years, values)!.Value;

        Assert.True(result.PValue > 0.1, $"p = {result.PValue}");
        Assert.Equal(0, result.SlopePerYear);
    }

    [Fact]
    public void TooFewPointsGiveNoResult() =>
        Assert.Null(TrendStatistics.Analyze([2001, 2002], [1, 2]));

    // ---------- yearly indicators ----------

    [Fact]
    public void TheIndicatorListIsTheClosedOne() =>
        Assert.Equal(
            [
                "frost_free_days", "last_spring_frost", "first_autumn_frost", "hot_days", "max_temperature",
                "growing_degree_days", "longest_dry_spell", "season_precipitation", "water_balance", "heavy_rain_days",
            ],
            YearlyIndicators.All.Select(i => i.Id));

    [Fact]
    public void FrostFreeSeasonRunsFromTheLastSpringFrostToTheFirstAutumnFrost()
    {
        var frosts = new[] { new DateOnly(2001, 1, 15), new DateOnly(2001, 4, 20), new DateOnly(2001, 10, 10), new DateOnly(2001, 12, 1) };
        var year = Year(2001, d => frosts.Contains(d) ? Mild with { TMin = -2 } : null);

        Assert.Equal(110, YearlyIndicators.LastSpringFrost(year));   // 20 April
        Assert.Equal(283, YearlyIndicators.FirstAutumnFrost(year));  // 10 October
        Assert.Equal(172, YearlyIndicators.FrostFreeDays(year));
    }

    [Fact]
    public void AYearWithoutFrostHasNoFrostFreeLength() =>
        Assert.Null(YearlyIndicators.FrostFreeDays(Year(2001)));

    [Fact]
    public void CountsHotDaysAndTheHottestDay()
    {
        var year = Year(2001, d => d is { Month: 7, Day: <= 4 } ? Mild with { TMax = 30 + d.Day } : null);

        Assert.Equal(4, YearlyIndicators.HotDays(year));
        Assert.Equal(34, YearlyIndicators.MaxTemperature(year));
    }

    [Fact]
    public void LongestDrySpellLooksOnlyAtTheGrowingSeason()
    {
        // 31 dry days in winter do not count; 20 dry days in June do. 0.9 mm is still a dry day.
        var year = Year(2001, d => d.Month == 1 || d is { Month: 6, Day: <= 20 } ? Mild with { Precipitation = 0.9 } : null);

        Assert.Equal(20, YearlyIndicators.LongestDrySpell(year));
    }

    [Fact]
    public void GrowingDegreeDaysSumWarmthAboveTenDegrees()
    {
        var year = Year(2001, d => d.Month == 7 ? Mild with { TMean = 20 } : null);

        Assert.Equal(310, YearlyIndicators.GrowingDegreeDays(year)); // 31 days × 10 °C
    }

    [Fact]
    public void WaterBalanceIsRainMinusEvaporation()
    {
        var wet = YearlyIndicators.WaterBalance(Year(2001))!.Value;
        var dry = YearlyIndicators.WaterBalance(Year(2001, d => d.Month is >= 4 and <= 9 ? Mild with { Precipitation = 0 } : null))!.Value;

        Assert.Equal(366, YearlyIndicators.SeasonPrecipitation(Year(2001))); // 183 days × 2 mm
        Assert.True(dry < 0);
        Assert.Equal(366, wet - dry, 6);
    }

    [Fact]
    public void HeavyRainDaysAreAboveTwentyMillimetres()
    {
        var year = Year(2001, d => d is { Month: 8, Day: 1 or 2 } ? Mild with { Precipitation = d.Day == 1 ? 20 : 35 } : null);

        Assert.Equal(1, YearlyIndicators.HeavyRainDays(year));
    }

    [Fact]
    public void AMissingDayLeavesTheYearWithoutAValue()
    {
        var days = Days(2001, 2001);
        days.Remove(new DateOnly(2001, 7, 10));
        var year = new YearWeather(2001, Lat, days);

        Assert.Null(YearlyIndicators.HotDays(year));
        Assert.Null(YearlyIndicators.LongestDrySpell(year));
        Assert.Null(YearlyIndicators.MaxTemperature(Year(2001, d => d.DayOfYear == 50 ? Mild with { TMax = null } : null)));
    }

    // ---------- which trends are shown ----------

    private static readonly ClimateTrendRules Rules = ClimateTrendRules.LoadDefault();

    private const int From = 1990;
    private const int To = 2019; // 30 years

    /// <summary>Years counted from <see cref="From"/>: 0, 1, 2, ...</summary>
    private static int N(DateOnly d) => d.Year - From;

    /// <summary>
    /// A hot day whose estimated evaporation is the same as a mild day's (Hargreaves: warmer, but a narrower
    /// day-night range), so that heat can be tested apart from the water balance.
    /// </summary>
    private static readonly WeatherDay HotSameEvaporation = Mild with { TMax = 31, TMin = 27.5 };

    /// <summary>Each year July gets one more hot day; nothing else changes.</summary>
    private static WeatherDay? MoreHotDays(DateOnly d) => d.Month == 7 && d.Day <= N(d) ? HotSameEvaporation : null;

    /// <summary>Each year June gets one more day without rain; nothing else changes clearly.</summary>
    private static WeatherDay? LongerDrySpell(DateOnly d) => d.Month == 6 && d.Day <= N(d) ? Mild with { Precipitation = 0 } : null;

    /// <summary>Each year August gets one more day of heavy rain.</summary>
    private static WeatherDay? MoreHeavyRain(DateOnly d) => d.Month == 8 && d.Day <= N(d) ? Mild with { Precipitation = 30 } : null;

    /// <summary>The last spring frost comes one day earlier each year; the first autumn frost stays on 1 November.</summary>
    private static WeatherDay? EarlierSpringFrost(DateOnly d) =>
        d.DayOfYear == 130 - N(d) || d is { Month: 11, Day: 1 } ? Mild with { TMin = -1 } : null;

    /// <summary>The first matching change wins.</summary>
    private static Func<DateOnly, WeatherDay?> All(params Func<DateOnly, WeatherDay?>[] changes) =>
        d => changes.Select(c => c(d)).FirstOrDefault(day => day is not null);

    private static ClimateTrendsResponse Analyze(
        Func<DateOnly, WeatherDay?> change, SiteConditions? site = null, int from = From, int to = To)
    {
        var findings = ClimateTrendAnalyzer.Find(Days(from, to, change), Lat, from, to, Rules);
        return ClimateTrendAnalyzer.Build("x", Lat, 21.48, findings, site ?? SiteConditions.Unknown, Rules);
    }

    private static string Outcome(ClimateTrendsResponse response, string id) =>
        response.Considered.Single(c => c.Id == id).Outcome;

    [Fact]
    public void TheShippedRulesAreValid()
    {
        Assert.Equal(30, Rules.MinYears);
        Assert.Equal(0.05, Rules.MaxPValue);
        Assert.Equal(15, Rules.ComparedYears);
        Assert.Equal(3, Rules.MaxTrends);
        Assert.Equal(YearlyIndicators.All.Select(i => i.Id).Order(), Rules.Indicators.Select(r => r.Id).Order());
    }

    [Fact]
    public void ASteadyRiseOverThirtyYearsIsShownAsFactsAboutThePast()
    {
        var response = Analyze(MoreHotDays);

        Assert.Equal("ok", response.Status);
        var trend = Assert.Single(response.Trends);
        Assert.Equal("hot_days", trend.Id);
        Assert.Equal("more_heat", trend.Change);
        Assert.Equal("up", trend.Direction);
        Assert.Equal("days", trend.Unit);
        Assert.Equal(7, trend.EarlyMean);    // years 0..14
        Assert.Equal(22, trend.RecentMean);  // years 15..29
        Assert.Equal((1990, 2004, 2005, 2019), (trend.EarlyFrom, trend.EarlyTo, trend.RecentFrom, trend.RecentTo));
        Assert.True(trend.PValue < 0.001);
        Assert.Equal(["heat_tolerant_varieties"], trend.AdviceCodes);
        Assert.Equal(30, trend.Years.Count);
        Assert.Equal(trend.Years.Count, trend.Values.Count);

        Assert.Equal(["regional_climate_grid"], response.NoteCodes);
        Assert.Equal("NASA POWER (MERRA-2)", response.Source);
        Assert.Equal("estimated", response.SourceKind);
        Assert.Equal(50, response.GridKm);
        // The hottest day jumps once (15 -> 31 °C) and stays: one step is not a trend.
        Assert.Equal("not_significant", Outcome(response, "max_temperature"));
        Assert.Equal("not_significant", Outcome(response, "growing_degree_days"));
    }

    [Fact]
    public void TheSameRiseOverFifteenYearsIsTooShortToShow()
    {
        var response = Analyze(
            d => d.Month == 7 && d.Day <= 2 * (d.Year - 2005) ? HotSameEvaporation : null, from: 2005, to: 2019);

        Assert.Equal("no_data", response.Status);
        Assert.Empty(response.Trends);
        Assert.Empty(response.NoteCodes);
        Assert.All(response.Considered, c => Assert.Equal("too_short", c.Outcome));
    }

    [Fact]
    public void AClearButTinyChangeIsNotShown()
    {
        // One hot day every year (so the hottest day never changes), one more per decade: 1, 2, 3 hot days.
        var response = Analyze(d => d.Month == 7 && d.Day <= 1 + N(d) / 10 ? HotSameEvaporation : null);

        var hot = response.Considered.Single(c => c.Id == "hot_days");
        Assert.True(hot.PValue < 0.05, $"p = {hot.PValue}");
        Assert.Equal("below_threshold", hot.Outcome);   // 1.3 -> 2.7 days: under the 3-day threshold
        Assert.Equal("no_clear_trends", response.Status);
        Assert.Empty(response.Trends);
        Assert.Equal(["regional_climate_grid"], response.NoteCodes);
    }

    [Fact]
    public void OneExtremeYearIsNotATrend()
    {
        var response = Analyze(d => d.Year == To && d.Month == 7 ? HotSameEvaporation with { TMax = 38 } : null);

        Assert.Equal("no_clear_trends", response.Status);
        Assert.Equal("not_significant", Outcome(response, "hot_days"));
        Assert.Equal("not_significant", Outcome(response, "max_temperature"));
    }

    [Fact]
    public void AYearWithAMissingDayIsLeftOutNotGuessed()
    {
        var days = Days(From - 1, To, MoreHotDays);
        days.Remove(new DateOnly(2000, 7, 20));

        var findings = ClimateTrendAnalyzer.Find(days, Lat, From - 1, To, Rules);

        var hot = findings.Assessments.Single(a => a.Indicator.Id == "hot_days");
        Assert.DoesNotContain(2000, hot.Years);
        Assert.Equal(30, hot.Years.Count);
        Assert.Equal(TrendOutcome.Shown, hot.Outcome);
    }

    [Fact]
    public void IndicatorsThatSayTheSameThingAreOneTrend()
    {
        var response = Analyze(EarlierSpringFrost);

        var trend = Assert.Single(response.Trends);
        Assert.Equal("frost_free_days", trend.Id);
        Assert.Equal("longer_frost_free", trend.Change);
        Assert.Equal(["last_spring_frost"], trend.AlsoSeenIn);
        Assert.Equal("merged", Outcome(response, "last_spring_frost"));
        Assert.Equal("not_significant", Outcome(response, "first_autumn_frost"));
        // Spring frost itself comes earlier, so there is no warning against sowing earlier.
        Assert.Equal(["use_longer_season"], trend.AdviceCodes);
        Assert.Equal(["regional_climate_grid", "frost_measured_in_air"], response.NoteCodes);
    }

    [Fact]
    public void ALongerSeasonFromLaterAutumnFrostWarnsAgainstSowingEarlier()
    {
        // The first autumn frost comes one day later each year; the last spring frost stays on 10 May.
        var response = Analyze(d => d.DayOfYear == 280 + N(d) || d is { Month: 5, Day: 10 } ? Mild with { TMin = -1 } : null);

        var trend = Assert.Single(response.Trends);
        Assert.Equal("frost_free_days", trend.Id);
        Assert.Equal(["first_autumn_frost"], trend.AlsoSeenIn);
        Assert.Equal(["use_longer_season", "do_not_sow_earlier"], trend.AdviceCodes);
    }

    [Fact]
    public void AtMostThreeTrendsAreShown()
    {
        var response = Analyze(All(MoreHotDays, LongerDrySpell, MoreHeavyRain, EarlierSpringFrost));

        Assert.Equal(3, response.Trends.Count);
        Assert.Contains(response.Considered, c => c.Outcome == "over_limit");
        Assert.Equal(response.Trends.OrderBy(t => t.PValue).Select(t => t.Id), response.Trends.Select(t => t.Id));
        Assert.Equal(3, response.Trends.Select(t => t.Change).Distinct().Count());
    }

    [Fact]
    public void AdviceForLightSoilDiffersFromTheGeneralOne()
    {
        var general = Assert.Single(Analyze(LongerDrySpell, new SiteConditions(LightSoil: false, SlopePct: 1)).Trends);
        var light = Assert.Single(Analyze(LongerDrySpell, new SiteConditions(LightSoil: true, SlopePct: 1)).Trends);

        Assert.Equal("longest_dry_spell", general.Id);
        Assert.Equal("drier", general.Change);
        Assert.Equal(["keep_soil_covered"], general.AdviceCodes);
        Assert.Equal(["keep_soil_covered", "drought_crops_on_light_soil"], light.AdviceCodes);
    }

    [Fact]
    public void WithoutParcelDataTheAdviceIsTheGeneralOne()
    {
        var response = Analyze(All(LongerDrySpell, MoreHeavyRain));

        Assert.Null(response.Site.Soil);
        Assert.Null(response.Site.SlopePct);
        Assert.Equal(["keep_soil_covered"], response.Trends.Single(t => t.Change == "drier").AdviceCodes);
        Assert.Equal(["protect_from_erosion"], response.Trends.Single(t => t.Change == "more_heavy_rain").AdviceCodes);
    }

    [Fact]
    public void ASlopeAddsAdviceAgainstErosionAndAWetterSeasonGetsNone()
    {
        var steep = Analyze(MoreHeavyRain, new SiteConditions(LightSoil: null, SlopePct: 8));
        var flat = Analyze(MoreHeavyRain, new SiteConditions(LightSoil: null, SlopePct: 2));

        Assert.Equal(["protect_from_erosion", "work_across_slope"], steep.Trends.Single(t => t.Id == "heavy_rain_days").AdviceCodes);
        Assert.Equal(["protect_from_erosion"], flat.Trends.Single(t => t.Id == "heavy_rain_days").AdviceCodes);
        Assert.Equal(8, steep.Site.SlopePct);

        // More rain in the season is a real change too, but there is nothing to advise: it is shown without advice.
        var wetter = steep.Trends.Single(t => t.Change == "wetter");
        Assert.Empty(wetter.AdviceCodes);
        Assert.NotEmpty(wetter.AlsoSeenIn);
    }

    [Fact]
    public void WarmerDaysAloneAreNotCalledDrought()
    {
        var response = Analyze(MoreHotDays);

        Assert.DoesNotContain(response.Trends, t => t.Change == "drier");
        Assert.DoesNotContain(response.Trends.SelectMany(t => t.AdviceCodes), c => c.Contains("soil", StringComparison.Ordinal));
        Assert.DoesNotContain("evaporation_estimated_from_temperature", response.NoteCodes);
    }

    [Fact]
    public void AWorseWaterBalanceFromHeatSaysThatRainDidNotChange()
    {
        // Hot days with cool nights: the estimated evaporation rises, the rain stays exactly the same.
        var response = Analyze(d => d.Month == 7 && d.Day <= N(d) ? Mild with { TMax = 31 } : null);

        var water = response.Trends.Single(t => t.Change == "drier");
        Assert.Equal("water_balance", water.Id);
        Assert.Empty(water.AlsoSeenIn);
        Assert.Equal("not_significant", Outcome(response, "season_precipitation"));
        Assert.Equal("not_significant", Outcome(response, "longest_dry_spell"));
        Assert.Contains("evaporation_estimated_from_temperature", response.NoteCodes);
    }

    [Fact]
    public void LessRainIsShownByTheRainItselfWithoutTheEvaporationNote()
    {
        // Each year 2 mm less rain on every day of one more week of the season.
        var response = Analyze(d => d.Month is >= 4 and <= 9 && d.DayOfYear - 91 < 3 * N(d) ? Mild with { Precipitation = 1 } : null);

        var water = Assert.Single(response.Trends);
        Assert.Equal("season_precipitation", water.Id);
        Assert.Equal("drier", water.Change);
        Assert.Equal("down", water.Direction);
        Assert.Equal(["water_balance"], water.AlsoSeenIn);
        Assert.DoesNotContain("evaporation_estimated_from_temperature", response.NoteCodes);
    }

    [Theory]
    [InlineData("pgl", "5", true)]    // light sand on top
    [InlineData("gs", "6", true)]     // weak rye complex
    [InlineData("gs", "2", false)]
    [InlineData("gl", null, false)]
    [InlineData(null, "7", true)]
    public void LightSoilComesFromTheTopTextureOrTheComplex(string? texture, string? complex, bool expected) =>
        Assert.Equal(expected, ClimateTrendAnalyzer.IsLightSoil(texture, complex, Rules));

    [Fact]
    public void SoilIsUnknownWithoutTextureAndComplex() =>
        Assert.Null(ClimateTrendAnalyzer.IsLightSoil(null, null, Rules));

    [Theory]
    [InlineData(52.199, 21.48, 52.0, 21.25)]
    [InlineData(50.3, 20.3, 50.5, 20.0)]
    [InlineData(52.26, 21.6, 52.5, 21.875)]
    public void PointsOfOneGridCellShareItsCentre(double lat, double lon, double cellLat, double cellLon) =>
        Assert.Equal((cellLat, cellLon), ClimateTrendsProvider.GridCell(lat, lon));

    [Fact]
    public void ReadsDaysFromANasaPowerAnswer()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "nasa-power-daily-2y.json"));

        var days = ClimateTrendAnalyzer.ToDays(NasaPowerClient.ParseDaily(json));

        Assert.True(days.Count >= 700, $"{days.Count} days");
        var day = days[new DateOnly(2024, 7, 1)];
        Assert.NotNull(day.TMin);
        Assert.NotNull(day.TMax);
        Assert.NotNull(day.Precipitation);
        Assert.True(day.TMax > day.TMin);
    }
}
