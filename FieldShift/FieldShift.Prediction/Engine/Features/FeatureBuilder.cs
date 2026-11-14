using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Features;

public sealed record FeatureBuildResult(PlotFeatures Features, IReadOnlyList<Reason> Reasons);

public static class FeatureBuilder
{
    public const int PlotLevel = -1;

    public static FeatureBuildResult Build(Plot plot, EngineSettings settings)
    {
        if (settings.Pedotransfer.Method != "saxtonRawls2006")
            throw new NotSupportedException(Fmt.Inv($"Unknown pedotransfer method '{settings.Pedotransfer.Method}'."));

        var reasons = new List<Reason>();
        var soil = plot.Soil;

        // pH: a lab test from the farmer beats the SoilGrids model.
        double ph;
        if (plot.Farmer.SoilTest?.PhH2OEstimate() is { } labPh)
        {
            ph = labPh;
            reasons.Add(Plotwide("feature.ph.source", StateVarId.Ph, ph,
                "pH from the farmer's soil test (pH KCl converted to pH H2O)."));
        }
        else
        {
            ph = soil.PhH2O.Median;
            reasons.Add(Plotwide("feature.ph.source", StateVarId.Ph, ph, "pH from SoilGrids (modelled)."));
        }

        var sand = soil.SandPct.Median;
        var clay = soil.ClayPct.Median;
        var soc = soil.OrganicCarbonGkg.Median;
        var om = SaxtonRawls2006.OrganicMatterPct(soc);

        var (field, wilting) = SaxtonRawls2006.Retention(sand, clay, om);
        var awc = SaxtonRawls2006.AwcMmPerM(sand, clay, om);
        reasons.Add(Plotwide("feature.awc", null, awc,
            Fmt.Inv($"Available water {awc:F0} mm/m (Saxton & Rawls 2006: field capacity {field:F3}, wilting point {wilting:F3}, OM {om:F1} %).")));

        if (clay > SaxtonRawls2006.MaxValidClayPct || om > SaxtonRawls2006.MaxValidOrganicMatterPct)
            reasons.Add(Plotwide("feature.awc.outOfRange", null, awc,
                "Clay or organic matter is outside the range the pedotransfer function was fitted on."));

        var b = settings.PhBuffer;
        var buffer = b.BaseCaOPerUnit + b.PerClayPct * clay + b.PerSocGkg * soc;
        reasons.Add(Plotwide("feature.phBuffer", StateVarId.Ph, buffer,
            Fmt.Inv($"Lime needed per pH unit: {buffer:F0} kg CaO/ha (approximation from clay and organic carbon).")));

        // kg C/ha = SOC (g/kg) · bulk density (t/m³ = kg/dm³) · depth (m) · 10 000 m²/ha  (the 1000s cancel).
        var bulkDensity = soil.BulkDensityGcm3?.Median ?? settings.Soil.DefaultBulkDensityGcm3;
        var humus = soc * bulkDensity * settings.Soil.TopsoilDepthM * 10_000.0;
        reasons.Add(Plotwide("feature.humusC", StateVarId.HumusC, humus,
            Fmt.Inv($"Initial humus {humus:F0} kg C/ha from SOC {soc:F1} g/kg, bulk density {bulkDensity:F2} g/cm³ ") +
            Fmt.Inv($"({(soil.BulkDensityGcm3 is null ? "default from settings" : "SoilGrids")}), depth {settings.Soil.TopsoilDepthM:F2} m.")));

        var features = new PlotFeatures
        {
            SandPct = sand,
            ClayPct = clay,
            InitialPhH2O = ph,
            InitialSocGkg = soc,
            InitialHumusCKgHa = humus,
            AwcMmPerM = awc,
            PhBufferCaOPerUnit = buffer
        };
        return new FeatureBuildResult(features, reasons);
    }

    private static Reason Plotwide(string code, StateVarId? variable, double value, string message) => new()
    {
        SeasonIndex = PlotLevel,
        Kind = ReasonKind.Suitability,
        Code = code,
        Var = variable,
        Value = value,
        Message = message
    };
}
