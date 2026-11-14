using FieldShift.Web.FieldProfile;

namespace TestProject1;

public class FieldProfileServiceTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 14, 14, 0, 0, TimeSpan.Zero);
    private readonly FieldProfileService _service = new();

    private static string Fixture(string name) => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", name));
    private static NasaPowerData Nasa(string name) => NasaPowerClient.Parse(Fixture(name));
    private static SoilGridsData Soil(string name) => SoilGridsClient.Parse(Fixture(name));

    [Fact]
    public void ValidData_Climate()
    {
        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), Soil("soilgrids-valid.json"), Now);
        var c = profile.Climate;

        Assert.Equal(125, profile.Location.ElevationM);
        Assert.Equal("NASA POWER, klimatologia 2001–2025 (siatka MERRA-2 ~50 km)", c.Source);
        Assert.Equal(
            new double?[] { 45.3, 38.1, 38.8, 41.1, 73.8, 66.6, 75.6, 62.0, 51.9, 48.7, 42.6, 44.0 },
            c.PrecipitationMm);
        Assert.Equal(628.5, c.AnnualPrecipitationMm!.Value, 1);
        Assert.Equal(371.0, c.SeasonPrecipitationMm!.Value, 1);
        Assert.Equal([4, 5, 6, 7, 8, 9, 10], c.GrowingSeasonMonths);
        Assert.Equal(214, c.GrowingSeasonDays);
        Assert.Equal([1, 2, 3, 4, 5, 9, 10, 11, 12], c.FrostRiskMonths);
        Assert.Equal(5, c.LastSpringFrostMonth);
        Assert.Equal(9, c.FirstAutumnFrostMonth);
        Assert.Equal([5, 6, 7, 8], c.HeatRiskMonths); // fixture T2M_MAX: May 31.2 … Aug 33.9
        Assert.Equal([8, 9], c.DryMonths);
        Assert.Equal(24, c.SoilMoistureDropPct);
    }

    [Fact]
    public void ValidData_Soil_SkipsInflatedSocTopLayer()
    {
        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), Soil("soilgrids-valid.json"), Now);
        var s = profile.Soil;

        Assert.NotNull(s);
        Assert.Equal(77.5, s.SandPct!.Value, 1);
        Assert.Equal(9.0, s.ClayPct!.Value, 1);
        Assert.Equal(13.5, s.SiltPct!.Value, 1);
        Assert.Equal(5.75, s.Ph!.Value, 2);
        Assert.Equal(15.3, s.OrganicCarbonGkg!.Value, 1); // 0–5 cm layer (75.3) skipped
        Assert.Equal("Lekka", s.SoilClass);
        Assert.Equal("Lekko kwaśna", s.PhClass);
        Assert.Equal("Średnia", s.OrganicMatterClass);
        Assert.Equal(
            [FieldProfileService.SocTopLayerSkippedWarning, FieldProfileService.NitrogenTopLayerSkippedWarning],
            profile.Warnings);
    }

    [Fact]
    public void ValidData_ExtraSoilProperties()
    {
        var s = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), Soil("soilgrids-valid.json"), Now).Soil!;

        Assert.Equal(1.99, s.NitrogenGkg!.Value, 2); // 0–5 cm (6.66) skipped: (1.67·10 + 2.21·15) / 25
        Assert.Equal("Średnia", s.NitrogenClass);
        Assert.Equal(21.8, s.CecCmolKg!.Value, 1);
        Assert.Equal("Wysoka", s.CecClass);
        Assert.Equal(1.30, s.BulkDensityGcm3!.Value, 2);
        Assert.Equal("Prawidłowa", s.CompactionClass);
        Assert.Equal(5.1, s.CoarseFragmentsPct!.Value, 1);
        Assert.Equal("Średnia", s.StoneClass);
    }

    [Fact]
    public void PoorSoil_AddsProblemSentencesToSummary()
    {
        static SoilGridsLayer Layer(string name, double dFactor, double top, double mid, double bottom) =>
            new(name, dFactor, null, new Dictionary<string, double?> { ["0-5cm"] = top, ["5-15cm"] = mid, ["15-30cm"] = bottom });

        var soil = new SoilGridsData(
        [
            Layer("sand", 10, 800, 800, 800),
            Layer("clay", 10, 50, 50, 50),
            Layer("nitrogen", 100, 50, 50, 50), // 0.5 g/kg
            Layer("cec", 10, 50, 50, 50), // 5 cmol(c)/kg
            Layer("bdod", 100, 170, 170, 170), // 1.70 g/cm³ on light soil
            Layer("cfvo", 10, 250, 250, 250), // 25 %
        ]);

        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), soil, Now);

        Assert.Equal("Niska", profile.Soil!.NitrogenClass);
        Assert.Equal("Niska", profile.Soil.CecClass);
        Assert.Equal("Zagęszczona", profile.Soil.CompactionClass);
        Assert.Equal("Duża", profile.Soil.StoneClass);
        Assert.Contains(profile.Summary, l => l.StartsWith("Mało azotu"));
        Assert.Contains(profile.Summary, l => l.StartsWith("Gleba słabo zatrzymuje składniki"));
        Assert.Contains(profile.Summary, l => l.StartsWith("Gleba może być zbita"));
        Assert.Contains(profile.Summary, l => l.StartsWith("Dużo kamieni"));
    }

    [Fact]
    public void ValidData_SummaryIsGeneratedInPolish()
    {
        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), Soil("soilgrids-valid.json"), Now);

        Assert.Equal(
        [
            "Sezon wegetacyjny: kwiecień–październik (~214 dni).",
            "Przymrozki możliwe do maja i od września.",
            "Opady: 629 mm/rok, 371 mm w sezonie (IV–IX).",
            "Upały powyżej 30 °C notowano w maju, czerwcu, lipcu i sierpniu.",
            "Gleba wysycha w sierpniu i wrześniu (wilgotność −24%).",
            "Gleba lekka, piaszczysta, lekko kwaśna – słabo zatrzymuje wodę.",
        ], profile.Summary);
        Assert.Equal(FieldProfileService.Disclaimer, profile.Disclaimer);
        Assert.Equal(Now, profile.GeneratedAtUtc);
    }

    [Fact]
    public void SoilGridsAllNull_SoilIsNullWithWarning()
    {
        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), Soil("soilgrids-all-null.json"), Now);

        Assert.Null(profile.Soil);
        Assert.Equal([FieldProfileService.SoilNoDataWarning], profile.Warnings);
        Assert.DoesNotContain(profile.Summary, line => line.StartsWith("Gleba lekka"));
    }

    [Fact]
    public void SoilGridsUnavailable_SoilIsNullWithWarning()
    {
        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), soilData: null, Now);

        Assert.Null(profile.Soil);
        Assert.Equal([FieldProfileService.SoilUnavailableWarning], profile.Warnings);
        Assert.NotNull(profile.Climate.AnnualPrecipitationMm);
    }

    [Fact]
    public void NasaFillValue_BecomesNullAndIsSkipped()
    {
        // Fixture: PRECTOTCORR JUL = -999 and GWETROOT MAR = -999 (MAR was the wettest month, 0.50).
        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-missing-values.json"), Soil("soilgrids-valid.json"), Now);
        var c = profile.Climate;

        Assert.Null(c.PrecipitationMm[6]);
        Assert.Null(c.SoilMoisture[2]);
        Assert.Equal(628.5 - 75.6, c.AnnualPrecipitationMm!.Value, 1);
        Assert.Equal(371.0 - 75.6, c.SeasonPrecipitationMm!.Value, 1);
        Assert.Equal(22, c.SoilMoistureDropPct); // (0.49 − 0.38) / 0.49
        Assert.Equal([8, 9], c.DryMonths);
        Assert.Contains(profile.Warnings, w => w.Contains("opadów") && w.Contains("lipiec"));
        Assert.Contains(profile.Warnings, w => w.Contains("wilgotności gleby") && w.Contains("marzec"));
    }

    [Fact]
    public void SocNotInflated_AllLayersAreUsed()
    {
        var soil = Soil("soilgrids-valid.json");
        var soc = soil.Layers.Single(l => l.Name == "soc");
        var notInflated = soc with
        {
            MeanByDepth = new Dictionary<string, double?> { ["0-5cm"] = 150, ["5-15cm"] = 133, ["15-30cm"] = 166 },
        };
        soil = new SoilGridsData(soil.Layers.Select(l => l.Name == "soc" ? notInflated : l).ToList());

        var profile = _service.Build(52.20, 21.48, Nasa("nasa-power-valid.json"), soil, Now);

        Assert.Equal(15.2, profile.Soil!.OrganicCarbonGkg!.Value, 1); // (15·5 + 13.3·10 + 16.6·15) / 30
        Assert.DoesNotContain(FieldProfileService.SocTopLayerSkippedWarning, profile.Warnings);
    }

    [Theory]
    [InlineData(new[] { 9 }, "we wrześniu")]
    [InlineData(new[] { 8, 9 }, "w sierpniu i wrześniu")]
    [InlineData(new[] { 7, 8, 9 }, "w lipcu, sierpniu i wrześniu")]
    public void PolishMonthList(int[] months, string expected)
    {
        Assert.Equal(expected, PolishMonths.InList(months));
    }
}
