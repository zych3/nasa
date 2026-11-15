using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Climate;

public static class Et0Calculator
{
    private const double SolarConstant = 0.0820;

    private const double RadiationToMm = 0.408;

    public static double ExtraterrestrialRadiation(double latitudeDeg, int dayOfYear)
    {
        var phi = latitudeDeg * Math.PI / 180.0;
        var angle = 2.0 * Math.PI / 365.0 * dayOfYear;

        var dr = 1.0 + 0.033 * Math.Cos(angle);              // eq. 23, inverse relative Earth–Sun distance
        var delta = 0.409 * Math.Sin(angle - 1.39);          // eq. 24, solar declination
        var cosOmega = Math.Clamp(-Math.Tan(phi) * Math.Tan(delta), -1.0, 1.0);
        var omegaS = Math.Acos(cosOmega);                    // eq. 25, sunset hour angle (clamped for polar day/night)

        return 24.0 * 60.0 / Math.PI * SolarConstant * dr *
               (omegaS * Math.Sin(phi) * Math.Sin(delta) + Math.Cos(phi) * Math.Cos(delta) * Math.Sin(omegaS));
    }

    public static double Hargreaves(double latitudeDeg, int dayOfYear, double tMinC, double tMaxC)
    {
        var tMean = (tMinC + tMaxC) / 2.0;
        var range = Math.Max(0.0, tMaxC - tMinC);
        var raMm = ExtraterrestrialRadiation(latitudeDeg, dayOfYear) * RadiationToMm;
        return Math.Max(0.0, 0.0023 * (tMean + 17.8) * Math.Sqrt(range) * raMm);
    }

    public static double Resolve(DailyWeather day, double latitudeDeg) =>
        day.Et0Mm ?? Hargreaves(latitudeDeg, day.Date.DayOfYear, day.TMinC, day.TMaxC);
}
