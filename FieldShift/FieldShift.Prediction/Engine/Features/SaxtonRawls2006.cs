namespace FieldShift.Prediction.Engine.Features;

/// <summary>
/// Soil water retention from texture and organic matter.
/// Saxton, K.E. and Rawls, W.J. (2006), "Soil water characteristic estimates by texture and organic matter for
/// hydrologic solutions", Soil Science Society of America Journal 70:1569–1578, eqs. 1–5 (first-solution
/// regressions with the second-stage corrections for the 33 kPa and 1500 kPa points).
/// Valid for clay ≤ 60 % and organic matter ≤ 8 %.
/// </summary>
public static class SaxtonRawls2006
{
    public const double MaxValidClayPct = 60;
    public const double MaxValidOrganicMatterPct = 8;

    /// <summary>Soil organic matter (%) from soil organic carbon (g/kg): OM = SOC · 1.724 / 10.</summary>
    public static double OrganicMatterPct(double socGkg) => socGkg * 0.1724;

    /// <returns>Volumetric water content (m³/m³) at 33 kPa (field capacity) and 1500 kPa (wilting point).</returns>
    public static (double FieldCapacity, double WiltingPoint) Retention(
        double sandPct, double clayPct, double organicMatterPct)
    {
        double s = sandPct / 100.0, c = clayPct / 100.0, om = organicMatterPct;

        var wiltFirst = -0.024 * s + 0.487 * c + 0.006 * om
                        + 0.005 * s * om - 0.013 * c * om + 0.068 * s * c + 0.031;
        var wilting = wiltFirst + (0.14 * wiltFirst - 0.02);

        var fieldFirst = -0.251 * s + 0.195 * c + 0.011 * om
                         + 0.006 * s * om - 0.027 * c * om + 0.452 * s * c + 0.299;
        var field = fieldFirst + (1.283 * fieldFirst * fieldFirst - 0.374 * fieldFirst - 0.015);

        return (field, wilting);
    }

    /// <summary>Plant-available water capacity in mm per metre of soil (field capacity minus wilting point).</summary>
    public static double AwcMmPerM(double sandPct, double clayPct, double organicMatterPct)
    {
        var (field, wilting) = Retention(sandPct, clayPct, organicMatterPct);
        return Math.Max(0.0, field - wilting) * 1000.0;
    }
}
