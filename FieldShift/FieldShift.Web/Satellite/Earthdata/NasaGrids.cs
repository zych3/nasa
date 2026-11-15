namespace FieldShift.Web.Satellite.Earthdata;

/// <summary>Cell of a point in the grids of the NASA products read at a point. Pure math.</summary>
public static class NasaGrids
{
    /// <summary>
    /// GPM IMERG 0.1° grid: index along longitude (−180…180) and latitude (−90…90); cell i covers
    /// [−180 + 0.1 i, −180 + 0.1 (i + 1)).
    /// </summary>
    public static (int LonIndex, int LatIndex) Imerg(double lat, double lon) =>
        (Math.Clamp((int)Math.Floor((lon + 180) / 0.1 + 1e-9), 0, 3599), Math.Clamp((int)Math.Floor((lat + 90) / 0.1 + 1e-9), 0, 1799));
    // (+1e-9: a point on a cell edge, e.g. 52.2, belongs to the cell that starts there despite rounding.)

    /// <summary>Centre of an IMERG cell.</summary>
    public static (double Lat, double Lon) ImergCentre(int lonIndex, int latIndex) =>
        (-90 + 0.1 * latIndex + 0.05, -180 + 0.1 * lonIndex + 0.05);

    // EASE-Grid 2.0 global (EPSG:6933, Lambert cylindrical equal-area on WGS 84, true scale at 30°), 9 km cells:
    // the grid of SMAP L3 enhanced and L4 (3856 columns × 1624 rows).
    private const double A = 6378137.0;
    private const double E2 = 0.0066943799901413165;
    private const double CellM = 9008.055210146;
    private const double X0 = -17367530.44516138;
    private const double Y0 = 7314540.83113623;
    public const int SmapColumns = 3856;
    public const int SmapRows = 1624;

    /// <summary>Row and column of the 9 km EASE-Grid 2.0 cell that contains the point.</summary>
    public static (int Row, int Column) Smap9Km(double lat, double lon)
    {
        var e = Math.Sqrt(E2);
        var phi1 = 30.0 * Math.PI / 180;
        var k0 = Math.Cos(phi1) / Math.Sqrt(1 - E2 * Math.Pow(Math.Sin(phi1), 2));
        var sin = Math.Sin(lat * Math.PI / 180);
        var q = (1 - E2) * (sin / (1 - E2 * sin * sin) - 1 / (2 * e) * Math.Log((1 - e * sin) / (1 + e * sin)));
        var x = A * k0 * lon * Math.PI / 180;
        var y = A * q / (2 * k0);
        var row = (int)Math.Floor((Y0 - y) / CellM);
        var column = (int)Math.Floor((x - X0) / CellM);
        return (Math.Clamp(row, 0, SmapRows - 1), Math.Clamp(column, 0, SmapColumns - 1));
    }
}
