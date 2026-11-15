using System.Globalization;
using System.Text;
using FieldShift.Web.FieldData;
using FieldShift.Web.MapLayers;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Elevation and slope of a Polish parcel from GUGiK's terrain model (NMT, 1 m grid, from airborne laser scanning).
/// Heights are asked for a grid of points inside the outline (at most <see cref="MaxSamples"/>, one request), and
/// the slope is that of the plane fitted to them: the field's overall fall, not the steepest spot.
/// </summary>
public sealed class GugikTerrainProvider(HttpClient http) : ITerrainProvider
{
    public const string Source = "Numeryczny model terenu GUGiK (siatka 1 m)";

    public const int MaxSamples = 150;

    /// <summary>Closer samples add nothing on a 1 m model for a whole-field slope.</summary>
    public const double MinSpacingM = 5;

    public string Id => "pl.nmt.v1";

    /// <summary>The terrain does not change; a year keeps the cache from growing stale forever.</summary>
    public TimeSpan CacheFor => TimeSpan.FromDays(365);

    public bool Supports(FieldLocation location) =>
        location is { CountryCode: PolandCountryProvider.Code, ParcelId: not null, Local.Srid: UldkService.Pl1992 };

    public string CacheKey(FieldLocation location) => location.ParcelId!;

    public async Task<TerrainInfo?> GetAsync(FieldLocation location, CancellationToken ct)
    {
        var samples = SamplePoints(location.Local!);
        using var response = await http.GetAsync(PointListQuery(samples), ct);
        response.EnsureSuccessStatusCode();
        var heights = ParseHeights(await response.Content.ReadAsStringAsync(ct));
        return Summarize(heights);
    }

    /// <summary>
    /// A square grid of points inside the outline, spaced so there are at most <see cref="MaxSamples"/>; tiny or
    /// narrow parcels with fewer than 3 grid points also get their corners' neighbourhood via the interior point
    /// and the outline's vertices.
    /// </summary>
    public static IReadOnlyList<LocalPoint> SamplePoints(LocalGeometry outline)
    {
        var ring = outline.Ring;
        var spacing = Math.Max(MinSpacingM, Math.Sqrt(outline.AreaM2 / MaxSamples));
        double minX = ring.Min(p => p.X), maxX = ring.Max(p => p.X);
        double minY = ring.Min(p => p.Y), maxY = ring.Max(p => p.Y);

        var points = new List<LocalPoint>();
        for (var y = minY + spacing / 2; y < maxY; y += spacing)
        {
            for (var x = minX + spacing / 2; x < maxX; x += spacing)
            {
                var p = new LocalPoint(x, y);
                if (LocalGeometry.Contains(ring, p))
                {
                    points.Add(p);
                }
            }
        }

        if (points.Count < 3)
        {
            points.Add(outline.Inside);
            points.AddRange(ring.Distinct().Take(MaxSamples - points.Count));
        }

        return points.Count > MaxSamples ? points.Take(MaxSamples).ToList() : points;
    }

    /// <summary>
    /// "GetHByPointList" query. The service takes geodetic coordinates: northing first, then easting.
    /// </summary>
    public static string PointListQuery(IReadOnlyList<LocalPoint> points)
    {
        var list = new StringBuilder();
        foreach (var p in points)
        {
            if (list.Length > 0)
            {
                list.Append(',');
            }

            list.Append(CultureInfo.InvariantCulture, $"{p.Y:F2} {p.X:F2}");
        }

        return "?request=GetHByPointList&list=" + Uri.EscapeDataString(list.ToString());
    }

    /// <summary>Parses "northing easting height,…" into points (easting, northing) with their heights.</summary>
    public static IReadOnlyList<(LocalPoint Point, double Height)> ParseHeights(string body)
    {
        var result = new List<(LocalPoint, double)>();
        foreach (var item in body.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var parts = item.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 3
                && double.TryParse(parts[0], NumberStyles.Float, CultureInfo.InvariantCulture, out var north)
                && double.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var east)
                && double.TryParse(parts[2], NumberStyles.Float, CultureInfo.InvariantCulture, out var h))
            {
                result.Add((new LocalPoint(east, north), h));
            }
        }

        return result;
    }

    /// <summary>
    /// Elevation range and slope of the least-squares plane h = a·x + b·y + c (slope = √(a² + b²) · 100 %).
    /// Null without at least 3 heights; the service answers 0.0 outside its coverage, so all zeros = no data.
    /// </summary>
    public static TerrainInfo? Summarize(IReadOnlyList<(LocalPoint Point, double Height)> samples)
    {
        if (samples.Count < 3 || samples.All(s => s.Height == 0))
        {
            return null;
        }

        // Centre the coordinates so the normal equations stay well conditioned.
        double mx = samples.Average(s => s.Point.X), my = samples.Average(s => s.Point.Y);
        double mh = samples.Average(s => s.Height);
        double sxx = 0, sxy = 0, syy = 0, sxh = 0, syh = 0;
        foreach (var (p, h) in samples)
        {
            double dx = p.X - mx, dy = p.Y - my, dh = h - mh;
            sxx += dx * dx;
            sxy += dx * dy;
            syy += dy * dy;
            sxh += dx * dh;
            syh += dy * dh;
        }

        var det = sxx * syy - sxy * sxy;
        // All points on one line (a very narrow strip): only the fall along it is known.
        var slope = Math.Abs(det) < 1e-9
            ? AlongLine(sxx, syy, sxh, syh)
            : Math.Sqrt(Math.Pow((sxh * syy - syh * sxy) / det, 2) + Math.Pow((syh * sxx - sxh * sxy) / det, 2));
        var slopePct = Math.Round(slope * 100, 1);

        return new TerrainInfo
        {
            Source = Source,
            ElevationMinM = Math.Round(samples.Min(s => s.Height), 1),
            ElevationMeanM = Math.Round(mh, 1),
            ElevationMaxM = Math.Round(samples.Max(s => s.Height), 1),
            SlopePct = slopePct,
            SlopeClass = DerivedIndices.SlopeClass(slopePct),
            Samples = samples.Count,
        };
    }

    private static double AlongLine(double sxx, double syy, double sxh, double syh)
    {
        var length2 = sxx + syy;
        return length2 < 1e-9 ? 0 : Math.Sqrt(sxh * sxh + syh * syh) / length2;
    }
}
