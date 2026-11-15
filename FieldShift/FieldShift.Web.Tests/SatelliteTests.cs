using FieldShift.Web.Satellite;
using FieldShift.Web.Satellite.Earthdata;

namespace TestProject1;

/// <summary>NASA satellite data at a point: DAP4 reader on real answers, grids, MODIS scaling, summaries.</summary>
public sealed class SatelliteTests
{
    private static byte[] Fixture(string name) =>
        File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "Fixtures", name));

    [Fact]
    public void Dap4_ReadsRealSmapL4Answer_WithChecksums()
    {
        // SMAP L4 2026-11-12 22:30, cell row 169 col 2158 (Mińsk Mazowiecki area).
        var values = Dap4Reader.Read(Fixture("smap-l4-point.dap"));

        Assert.Equal(52.15, values["cell_lat"], 2);
        Assert.Equal(21.52, values["cell_lon"], 2);
        Assert.InRange(values["sm_rootzone"], 0.0, 1.0);
        Assert.InRange(values["sm_surface"], 0.0, 1.0);
    }

    [Fact]
    public void Dap4_ReadsRealImergAnswer()
    {
        // IMERG Late daily 2026-11-10 at 52.15 N 21.45 E.
        var values = Dap4Reader.Read(Fixture("imerg-day-point.dap"));

        Assert.Equal(8.135, values["precipitation"], 3);
    }

    [Fact]
    public void Dap4_RejectsABrokenChecksum()
    {
        var bytes = Fixture("imerg-day-point.dap");
        bytes[^8] ^= 0xFF; // a byte of the value

        Assert.Throws<FormatException>(() => Dap4Reader.Read(bytes));
    }

    [Fact]
    public void Crc32_MatchesTheStandardCheckValue() =>
        Assert.Equal(0xCBF43926u, Dap4Reader.Crc32("123456789"u8));

    [Fact]
    public void Grids_PointToTheRightCells()
    {
        Assert.Equal((2014, 1422), NasaGrids.Imerg(52.2, 21.48));
        var (lat, lon) = NasaGrids.ImergCentre(2014, 1421);
        Assert.Equal(52.15, lat, 6);
        Assert.Equal(21.45, lon, 6);

        // Verified against the cell_lat / cell_lon NASA returned for this cell.
        Assert.Equal((169, 2158), NasaGrids.Smap9Km(52.2, 21.48));
    }

    [Fact]
    public void Rain_SumsCountsAndDrySpell()
    {
        var start = new DateOnly(2026, 10, 1);
        var days = Enumerable.Range(0, 30).Select(i => new RainDay(start.AddDays(i), i switch
        {
            5 => 25.0,  // heavy
            25 => 3.0,
            >= 26 => 0.2, // last 4 days dry
            _ => 1.0,
        })).ToList();

        var rain = NasaRealtimeService.SummarizeRain(days);

        Assert.Equal(SatelliteStatus.Ok, rain.Status);
        Assert.Equal(new DateOnly(2026, 10, 30), rain.LatestDate);
        Assert.Equal(0.2, rain.Last1Mm);
        Assert.Equal(1.0 + 1.0 + 3.0 + 4 * 0.2, rain.Last7Mm!.Value, 6);
        Assert.Equal(1, rain.HeavyRainDays);
        Assert.Equal(4, rain.DryDaysInRow);
    }

    [Fact]
    public void Rain_WithoutValues_IsNoData() =>
        Assert.Equal(SatelliteStatus.NoData,
            NasaRealtimeService.SummarizeRain([new RainDay(new DateOnly(2026, 1, 1), null)]).Status);

    [Theory]
    [InlineData(0.30, 0.49, "below")]
    [InlineData(0.48, 0.49, "normal")]
    [InlineData(0.60, 0.49, "above")]
    [InlineData(0.30, null, null)]
    public void SoilWetness_ComparedWithItsNormal(double wetness, double? normal, string? expected) =>
        Assert.Equal(expected, NasaRealtimeService.WetnessLevel(wetness, normal));

    [Fact]
    public void Modis_ScalingAndFillValues()
    {
        Assert.Equal(0.7596, SatelliteMath.Ndvi(7596)!.Value, 6);
        Assert.Null(SatelliteMath.Ndvi(-3000));
        Assert.Equal(26.85, SatelliteMath.LstCelsius(15000)!.Value, 2);
        Assert.Null(SatelliteMath.LstCelsius(0));
        Assert.Equal(2.5, SatelliteMath.EtMmPerDay(200)!.Value, 6);
        Assert.Null(SatelliteMath.EtMmPerDay(32765));
    }

    [Fact]
    // MODIS composites start on fixed days of the year: in leap year 2024 that is 9 June, not 10 June.
    public void Modis_NormalsFromTheSameDayOfYear()
    {
        var points = SatelliteMath.WithNormals(
            [(new DateOnly(2026, 6, 10), 0.60), (new DateOnly(2026, 6, 26), null)],
            [(new DateOnly(2025, 6, 10), 0.80), (new DateOnly(2024, 6, 9), 0.70), (new DateOnly(2025, 6, 26), 0.75)]);

        Assert.Equal(0.75, points[0].Normal!.Value, 6);
        Assert.Equal(new DateOnly(2026, 6, 10), SatelliteMath.Latest(points)!.Date);
        Assert.Equal(SatelliteLevel.Below, SatelliteMath.NdviLevel(points[0]));
    }

    [Fact]
    public void Ornl_ParsesDatesAndSubsets()
    {
        Assert.Empty(OrnlModisClient.ParseDates("\"No MOD13Q1 data available for 1 2 location.\""));
        var dates = OrnlModisClient.ParseDates(
            """{"dates":[{"modis_date":"A2025177","calendar_date":"2025-06-26"},{"modis_date":"A2025161","calendar_date":"2025-06-10"}]}""");
        Assert.Equal(["A2025161", "A2025177"], dates.Select(d => d.Code));

        var subset = OrnlModisClient.ParseSubset(
            """{"subset":[{"calendar_date":"2025-06-10","data":[7596]},{"calendar_date":"2025-06-26","data":[]}]}""").ToList();
        Assert.Equal([(new DateOnly(2025, 6, 10), 7596)], subset);
    }

    [Fact]
    public void Cmr_ParsesGranules()
    {
        var granules = EarthdataClient.ParseGranules(
            """{"feed":{"entry":[{"title":"SMAP_L4_SM_gph_20261112T223000_Vv8013_001.h5_u9loH5HD","collection_concept_id":"C3480440870-NSIDC_CPRD","time_start":"2026-11-12T21:00:00.000Z"}]}}""");

        var g = Assert.Single(granules);
        Assert.Equal("C3480440870-NSIDC_CPRD", g.CollectionId);
        Assert.Equal(21, g.Start.UtcDateTime.Hour);
        Assert.Equal("%5B169%5D", EarthdataClient.EscapeConstraint("[169]"));
    }
}
