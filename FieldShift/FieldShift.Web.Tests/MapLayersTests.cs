using System.Text.Json;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using FieldShift.Web.MapLayers;

namespace TestProject1;

public class MapLayersTests
{
    private static readonly YearMonth From = new(2024, 1);
    private static readonly YearMonth To = new(2025, 12);
    private static readonly DateTimeOffset Now = new(2026, 11, 14, 19, 0, 0, TimeSpan.Zero);
    private static readonly DateOnly Today = new(2026, 11, 14);

    private static readonly string FixtureJson =
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "nasa-power-daily-2y.json"));

    private static NasaPowerDailyData Daily() => NasaPowerClient.ParseDaily(FixtureJson);

    /// <summary>Raw fixture values for one month, read independently of the production parser (-999 skipped).</summary>
    private static List<double> RawDays(string parameter, int year, int month)
    {
        using var doc = JsonDocument.Parse(FixtureJson);
        var prefix = $"{year:D4}{month:D2}";
        return doc.RootElement.GetProperty("properties").GetProperty("parameter").GetProperty(parameter)
            .EnumerateObject()
            .Where(p => p.Name.StartsWith(prefix, StringComparison.Ordinal))
            .Select(p => p.Value.GetDouble())
            .Where(v => v != -999)
            .ToList();
    }

    private static MapLayersRequest AllLayers() =>
        new(52.20, 21.48, From, To, LayerDefinitions.All.Select(d => d.Id).ToList());

    private static SoilProfile LightSoil() => new()
    {
        Source = "test", Description = "test", SoilClass = "Lekka", SandPct = 77.5, ClayPct = 9.0, Ph = 5.75,
    };

    // ------------------------------------------------------------ aggregation

    [Fact]
    public void Compose_AllArraysHaveSameLengthAsDates()
    {
        var response = MapLayersService.Compose(AllLayers(), Daily(), true, LightSoil(), null, Now);

        Assert.Equal(24, response.Dates.Count);
        Assert.Equal("2024-01", response.Dates[0]);
        Assert.Equal("2025-12", response.Dates[^1]);
        Assert.Equal(23, response.DefaultIndex);
        Assert.Equal("soilMoisture", response.DefaultLayerId);
        Assert.Equal(9, response.Layers.Count);
        foreach (var layer in response.Layers)
        {
            Assert.Equal(24, layer.Values.Count);
            if (layer.Anomalies is not null) Assert.Equal(24, layer.Anomalies.Count);
            foreach (var extra in layer.Extra?.Values ?? []) Assert.Equal(24, extra.Count);
        }
    }

    [Fact]
    public void Aggregate_PrecipitationSumAndTemperatureMean_MatchDailyValues()
    {
        var climate = MonthlyAggregator.Aggregate(Daily(), From, To);

        // 2024-02 is complete (29 days, leap year): plain sum / mean.
        var feb = RawDays("PRECTOTCORR", 2024, 2);
        Assert.Equal(29, feb.Count);
        Assert.Equal(feb.Sum(), climate.PrecipitationSum[1]!.Value, 6);
        Assert.Equal(RawDays("T2M", 2024, 2).Average(), climate.TempMean[1]!.Value, 6);
        Assert.Equal(RawDays("T2M_MAX", 2024, 2).Max(), climate.TempMax[1]!.Value, 6);
        Assert.Equal(RawDays("T2M_MIN", 2024, 2).Min(), climate.TempMin[1]!.Value, 6);
    }

    [Fact]
    public void Aggregate_CountsHeatFrostAndExtremeRainDays()
    {
        var climate = MonthlyAggregator.Aggregate(Daily(), From, To);

        // July 2025 (index 18) and January 2025 (index 12) are complete months.
        Assert.Equal(RawDays("T2M_MAX", 2025, 7).Count(v => v > 30), climate.HeatDays[18]);
        Assert.Equal(RawDays("T2M_MIN", 2025, 1).Count(v => v < 0), climate.FrostDays[12]);
        Assert.Equal(RawDays("PRECTOTCORR", 2025, 7).Count(v => v > 20), climate.ExtremeRainDays[18]);
        Assert.Equal(RawDays("PRECTOTCORR", 2025, 7).Max(), climate.MaxDailyPrecipitation[18]);
        Assert.True(climate.HeatDays[18] > 0, "fixture should have hot July days");
        Assert.True(climate.FrostDays[12] > 0, "fixture should have frosty January days");
    }

    [Fact]
    public void Aggregate_FillValues_SkipDaysAndRescaleSums_NullForMissingMonth()
    {
        var climate = MonthlyAggregator.Aggregate(Daily(), From, To);

        // 2024-01: 2 of 31 precipitation days are -999 → sum of 29 days scaled to 31.
        var jan = RawDays("PRECTOTCORR", 2024, 1);
        Assert.Equal(29, jan.Count);
        Assert.Equal(jan.Sum() * 31 / 29, climate.PrecipitationSum[0]!.Value, 6);

        // 2024-07-10 T2M is -999 → mean of the other 30 days.
        Assert.Equal(RawDays("T2M", 2024, 7).Average(), climate.TempMean[6]!.Value, 6);

        // 2025-03: every GWETROOT day is -999 → null, and plantStress for that month is null too.
        Assert.Null(climate.SoilMoistureMean[14]);
        var response = MapLayersService.Compose(AllLayers(), Daily(), true, LightSoil(), null, Now);
        Assert.Null(response.Layers.Single(l => l.Id == "soilMoisture").Values[14]);
        Assert.Null(response.Layers.Single(l => l.Id == "plantStress").Values[14]);
        Assert.Contains(response.Warnings, w => w.Contains("Wilgotność gleby"));
    }

    [Fact]
    public void Aggregate_EvaporationIsConvertedFromMegajoulesToMm()
    {
        var climate = MonthlyAggregator.Aggregate(Daily(), From, To);

        Assert.Equal(RawDays("EVPTRNS", 2025, 6).Sum() * 0.408, climate.EvaporationSum[17]!.Value, 6);
    }

    // ------------------------------------------------------------ anomalies and trend

    [Fact]
    public void Anomalies_MeanPerCalendarMonthIsZero()
    {
        var climate = MonthlyAggregator.Aggregate(Daily(), From, To);
        var anomalies = TrendCalculator.Anomalies(climate.PrecipitationSum, climate.Months);

        for (var m = 1; m <= 12; m++)
        {
            var sameMonth = Enumerable.Range(0, 24).Where(i => climate.Months[i].Month == m && anomalies[i].HasValue)
                .Select(i => anomalies[i]!.Value).ToList();
            Assert.NotEmpty(sameMonth);
            Assert.Equal(0, sameMonth.Average(), 9);
        }
    }

    [Fact]
    public void Trend_RisingSeriesIsPositive_AndFlatIsZero()
    {
        var months = YearMonth.Range(new YearMonth(2016, 1), new YearMonth(2025, 12));
        var rising = months.Select(m => (double?)(10 + 0.5 * (m.Year - 2016))).ToArray(); // +0.5 / year
        var flat = months.Select(_ => (double?)7).ToArray();

        Assert.Equal(5.0, TrendCalculator.TrendPerDecade(rising, months, YearlyAggregation.Mean)!.Value, 9);
        Assert.Equal(60.0, TrendCalculator.TrendPerDecade(rising, months, YearlyAggregation.Sum)!.Value, 9);
        Assert.Equal(0, TrendCalculator.TrendPerDecade(flat, months, YearlyAggregation.Mean)!.Value, 9);
    }

    [Fact]
    public void Trend_IgnoresIncompleteYears()
    {
        var months = YearMonth.Range(new YearMonth(2024, 1), new YearMonth(2025, 12));
        var values = months.Select(m => (double?)m.Year).ToArray();
        values[14] = null; // 2025 no longer complete → only one full year → no trend

        Assert.Null(TrendCalculator.TrendPerDecade(values, months, YearlyAggregation.Mean));
    }

    // ------------------------------------------------------------ derived indices

    [Theory]
    [InlineData(0.30, 5.0, 68)] // 100 × (0.6 × 0.8 + 0.4 × 0.5)
    [InlineData(0.60, 0.0, 0)] // wet, no heat
    [InlineData(0.20, 12.0, 100)] // both clamped to 1
    [InlineData(0.50, 10.0, 40)] // heat only
    public void PlantStress_KnownInputs(double moisture, double heatDays, double expected)
    {
        Assert.Equal(expected, DerivedIndices.PlantStress(moisture, heatDays));
    }

    [Theory]
    [InlineData(2.0, 1.0, 80)] // light soil: 100 × (0.6 × 2/3 + 0.4 × 1.0) × 1.0
    [InlineData(2.0, 0.5, 40)] // same, flat terrain
    [InlineData(0.0, 1.0, 40)] // no heavy rain: soil term only
    [InlineData(3.0, 1.6, 100)] // capped at 100
    public void ErosionRisk_LightSoil_KnownInputs(double extremeDays, double slopeFactor, double expected)
    {
        var susceptibility = DerivedIndices.SoilSusceptibility("Lekka");
        Assert.Equal(1.0, susceptibility);
        Assert.Equal(expected, DerivedIndices.ErosionRisk(extremeDays, susceptibility, slopeFactor));
    }

    [Theory]
    [InlineData(null, 1.0)]
    [InlineData(1.2, 0.5)]
    [InlineData(2.0, 1.0)]
    [InlineData(6.0, 1.0)]
    [InlineData(8.0, 1.3)]
    [InlineData(12.5, 1.6)]
    public void SlopeFactor_Thresholds(double? slopePct, double expected)
    {
        Assert.Equal(expected, DerivedIndices.SlopeFactor(slopePct));
    }

    [Fact]
    public void DemoLocation_MatchedWithin2Km_AndNoSlopeWarningOtherwise()
    {
        var demo = new DemoLocation { Name = "Pole testowe", Lat = 52.205, Lon = 21.485, SlopePct = 1.2 };
        Assert.Equal(demo, DerivedIndices.FindDemoLocation(52.20, 21.48, [demo])); // ~0.65 km
        Assert.Null(DerivedIndices.FindDemoLocation(52.30, 21.48, [demo])); // ~10 km

        var withSlope = MapLayersService.Compose(AllLayers(), Daily(), true, LightSoil(), demo, Now);
        Assert.Equal("płasko", withSlope.Static.Terrain!.SlopeClass);
        Assert.DoesNotContain(MapLayersService.NoSlopeWarning, withSlope.Warnings);

        var withoutSlope = MapLayersService.Compose(AllLayers(), Daily(), true, LightSoil(), null, Now);
        Assert.Null(withoutSlope.Static.Terrain);
        Assert.Contains(MapLayersService.NoSlopeWarning, withoutSlope.Warnings);
    }

    [Fact]
    public void Compose_NoSoil_UsesDefaultSusceptibilityAndWarns()
    {
        var response = MapLayersService.Compose(AllLayers(), Daily(), true, soil: null, null, Now);

        Assert.Null(response.Static.Soil);
        Assert.Contains(MapLayersService.NoSoilForErosionWarning, response.Warnings);
        var climate = MonthlyAggregator.Aggregate(Daily(), From, To);
        Assert.Equal(DerivedIndices.ErosionRisk(climate.ExtremeRainDays[0], 0.6, 1.0),
            response.Layers.Single(l => l.Id == "erosionRisk").Values[0]);
    }

    [Fact]
    public void Compose_EvaporationUnavailable_LayerOmittedWithWarning()
    {
        var response = MapLayersService.Compose(AllLayers(), Daily(), evaporationAvailable: false, LightSoil(), null, Now);

        Assert.DoesNotContain(response.Layers, l => l.Id == "evaporation");
        Assert.Contains(MapLayersService.NoEvaporationWarning, response.Warnings);
    }

    // ------------------------------------------------------------ legend

    [Theory]
    [InlineData(19.99, "#F5E6C8")]
    [InlineData(20.0, "#B5D4F4")] // boundary belongs to the next stop (value < max)
    [InlineData(39.0, "#B5D4F4")]
    [InlineData(70.0, "#0C447C")]
    [InlineData(500.0, "#0C447C")]
    [InlineData(-5.0, "#F5E6C8")]
    public void Legend_StopFor_PicksFirstStopBelowMax(double value, string expectedColor)
    {
        var legend = LayerDefinitions.Find("precipitation")!.Legend;
        Assert.Equal(expectedColor, LayerDefinitions.StopFor(legend, value)!.Color);
    }

    [Fact]
    public void Legend_StopFor_NullValueHasNoColor()
    {
        Assert.Null(LayerDefinitions.StopFor(LayerDefinitions.Find("precipitation")!.Legend, null));
    }

    [Fact]
    public void Legends_AreAscendingWithOpenLastStop()
    {
        foreach (var legend in LayerDefinitions.All.SelectMany(d => new[] { d.Legend, d.AnomalyLegend }).OfType<Legend>())
        {
            Assert.Null(legend.Stops[^1].Max);
            var bounds = legend.Stops.Take(legend.Stops.Count - 1).Select(s => s.Max!.Value).ToList();
            Assert.Equal(bounds.OrderBy(b => b), bounds);
            Assert.All(legend.Stops, s => Assert.Matches("^#[0-9A-F]{6}$", s.Color));
        }
    }

    // ------------------------------------------------------------ validation

    [Fact]
    public void Validation_Defaults_LastTenFullYears_AllLayers()
    {
        var v = MapLayersRequestValidator.Validate(52.2, 21.48, null, null, null, Today);

        Assert.True(v.IsValid);
        Assert.Equal(new YearMonth(2016, 1), v.Request!.From);
        Assert.Equal(new YearMonth(2025, 12), v.Request.To);
        Assert.Equal(LayerDefinitions.All.Select(d => d.Id), v.Request.LayerIds);
    }

    [Theory]
    [InlineData("2025-12", "2024-01", "from")] // from after to
    [InlineData("2010-01", "2025-12", "from")] // 16 years > 15
    [InlineData("2016-01", "2026-11", "to")] // current month is not complete
    [InlineData("2016-1", "2025-12", "from")] // bad format
    [InlineData("2016-13", "2025-12", "from")] // bad month
    [InlineData("1975-01", "1980-12", "from")] // before NASA POWER daily data
    public void Validation_BadDateRange(string from, string to, string errorKey)
    {
        var v = MapLayersRequestValidator.Validate(52.2, 21.48, from, to, null, Today);

        Assert.False(v.IsValid);
        Assert.True(v.Errors.ContainsKey(errorKey));
    }

    [Fact]
    public void Validation_UnknownLayer_AndCoordinates()
    {
        var unknown = MapLayersRequestValidator.Validate(52.2, 21.48, null, null, "precipitation,ndvi", Today);
        Assert.False(unknown.IsValid);
        Assert.Contains("ndvi", unknown.Errors["layers"][0]);

        var coords = MapLayersRequestValidator.Validate(95, null, null, null, null, Today);
        Assert.True(coords.Errors.ContainsKey("lat"));
        Assert.True(coords.Errors.ContainsKey("lon"));
    }

    [Fact]
    public void Validation_LayersAreDeduplicatedAndSortedByOrder()
    {
        var v = MapLayersRequestValidator.Validate(52.2, 21.48, "2024-01", "2025-12", " erosionRisk,precipitation , precipitation", Today);

        Assert.Equal(["precipitation", "erosionRisk"], v.Request!.LayerIds);
    }
}
