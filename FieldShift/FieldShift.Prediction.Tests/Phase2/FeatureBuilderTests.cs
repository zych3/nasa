using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Tests.Support;

namespace FieldShift.Prediction.Tests.Phase2;

public class FeatureBuilderTests
{
    [Fact]
    public void UsesSoilGridsPhWhenThereIsNoSoilTest()
    {
        var result = FeatureBuilder.Build(Fixture.PlotWithHistory(), Fixture.Settings);

        Assert.Equal(5.75, result.Features.InitialPhH2O);
        var reason = Assert.Single(result.Reasons, r => r.Code == "feature.ph.source");
        Assert.Contains("SoilGrids", reason.Message);
    }

    [Fact]
    public void FarmerSoilTestOverridesSoilGridsPh()
    {
        var plot = Fixture.PlotWithHistory() with
        {
            Farmer = new FarmerInputs { SoilTest = new SoilTest { SampledOn = new DateOnly(2025, 4, 1), PhKCl = 5.0 } }
        };

        var result = FeatureBuilder.Build(plot, Fixture.Settings);

        Assert.Equal(5.7, result.Features.InitialPhH2O, 6);
        var reason = Assert.Single(result.Reasons, r => r.Code == "feature.ph.source");
        Assert.Contains("soil test", reason.Message);
    }

    [Fact]
    public void PhBufferFollowsTheSettingsFormula()
    {
        // 1000 + 80 * clay 9 % + 40 * SOC 15.3 g/kg
        var result = FeatureBuilder.Build(Fixture.PlotWithHistory(), Fixture.Settings);

        Assert.Equal(1000 + 80 * 9 + 40 * 15.3, result.Features.PhBufferCaOPerUnit, 6);
    }

    [Fact]
    public void CopiesTextureAndOrganicCarbon()
    {
        var f = FeatureBuilder.Build(Fixture.PlotWithHistory(), Fixture.Settings).Features;

        Assert.Equal(77.5, f.SandPct);
        Assert.Equal(9, f.ClayPct);
        Assert.Equal(15.3, f.InitialSocGkg);
    }

    [Fact]
    public void HumusStockUsesTheDefaultBulkDensityFromSettings()
    {
        // SOC 15.3 g/kg * 1.4 g/cm3 * 0.3 m * 10 000 = 64 260 kg C/ha
        var result = FeatureBuilder.Build(Fixture.PlotWithHistory(), Fixture.Settings);

        Assert.Equal(64_260, result.Features.InitialHumusCKgHa, 6);
        Assert.Contains("default from settings", result.Reasons.Single(r => r.Code == "feature.humusC").Message);
    }

    [Fact]
    public void HumusStockPrefersSoilGridsBulkDensity()
    {
        var plot = Fixture.PlotWithHistory();
        plot = plot with { Soil = plot.Soil with { BulkDensityGcm3 = 1.2 } };

        var result = FeatureBuilder.Build(plot, Fixture.Settings);

        Assert.Equal(15.3 * 1.2 * 0.3 * 10_000, result.Features.InitialHumusCKgHa, 6);
        Assert.Contains("SoilGrids", result.Reasons.Single(r => r.Code == "feature.humusC").Message);
    }

    [Theory]
    [InlineData(0, 0.3)]
    [InlineData(1.4, 0)]
    [InlineData(3.0, 0.3)]
    [InlineData(1.4, 2)]
    public void RejectsImplausibleSoilSettings(double bulkDensity, double depth)
    {
        var settings = Fixture.Settings with { Soil = new Engine.SoilSettings { DefaultBulkDensityGcm3 = bulkDensity, TopsoilDepthM = depth } };

        var report = Engine.Validation.KnowledgeBaseValidator.Validate(Fixture.Kb, settings);

        Assert.True(report.HasError("settings.soil"));
    }

    [Fact]
    public void AwcForTheSandyPlotIsLowButPositive()
    {
        var f = FeatureBuilder.Build(Fixture.PlotWithHistory(), Fixture.Settings).Features;

        Assert.InRange(f.AwcMmPerM, 60, 130);
    }

    [Fact]
    public void WarnsWhenTextureIsOutsideTheFittedRange()
    {
        var plot = Fixture.PlotWithHistory() with
        {
            Soil = Fixture.PlotWithHistory().Soil with { ClayPct = 70, SandPct = 10, SiltPct = 20 }
        };

        var result = FeatureBuilder.Build(plot, Fixture.Settings);

        Assert.Contains(result.Reasons, r => r.Code == "feature.awc.outOfRange");
    }
}

public class SaxtonRawls2006Tests
{
    [Fact]
    public void LoamMatchesHandCalculationFromTheEquations()
    {
        // sand 40 %, clay 20 %, OM 2.5 %, worked by hand from eqs. 1-5 of the paper:
        // theta1500 = 0.1370, theta33 = 0.2796 -> AWC 142.6 mm/m
        var (field, wilting) = SaxtonRawls2006.Retention(40, 20, 2.5);

        Assert.Equal(0.2796, field, 3);
        Assert.Equal(0.1370, wilting, 3);
        Assert.Equal(142.6, SaxtonRawls2006.AwcMmPerM(40, 20, 2.5), 0);
    }

    [Fact]
    public void ConvertsOrganicCarbonToOrganicMatter()
    {
        Assert.Equal(2.6377, SaxtonRawls2006.OrganicMatterPct(15.3), 3);
    }

    // Typical plant-available water ranges by texture class (mm per m of soil), as tabulated in FAO-56 Table 19
    // and NRCS soil survey guidance. The bands are deliberately wide: they guard against unit and sign errors,
    // not against model differences.
    [Theory]
    [InlineData("sand", 90, 4, 0.5, 30, 100)]
    [InlineData("loamy sand", 82, 8, 1.0, 50, 120)]
    [InlineData("sandy loam", 65, 12, 1.5, 80, 150)]
    [InlineData("loam", 40, 20, 2.5, 110, 190)]
    [InlineData("silt loam", 20, 15, 2.5, 120, 210)]
    [InlineData("clay loam", 33, 33, 2.5, 90, 190)]
    [InlineData("clay", 20, 55, 2.5, 60, 170)]
    public void AwcFallsInTheTypicalRangeForTheTextureClass(
        string textureClass, double sand, double clay, double om, double min, double max)
    {
        var awc = SaxtonRawls2006.AwcMmPerM(sand, clay, om);

        Assert.True(awc >= min && awc <= max, $"{textureClass}: AWC {awc:F1} mm/m is outside [{min}, {max}].");
    }

    [Fact]
    public void MoreOrganicMatterNeverReducesAwcOnSandySoil()
    {
        var low = SaxtonRawls2006.AwcMmPerM(80, 8, 1);
        var high = SaxtonRawls2006.AwcMmPerM(80, 8, 4);

        Assert.True(high >= low);
    }
}
