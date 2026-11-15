using FieldShift.Web.FieldProfile;

namespace FieldShift.Web.FieldData;

/// <summary>
/// Where a field is: a point inside it (WGS84) and, when a national parcel register found it, the parcel id and
/// its outline in the country's own metric grid (Poland: EPSG:2180). Point-only locations (map layers) have no parcel.
/// </summary>
public sealed record FieldLocation(double Lat, double Lon)
{
    /// <summary>ISO 3166-1 alpha-2 code of the country whose register found the parcel ("PL"); null if none did.</summary>
    public string? CountryCode { get; init; }

    /// <summary>Parcel id in the national register, e.g. "141205_2.0008.60"; null for a bare point.</summary>
    public string? ParcelId { get; init; }

    /// <summary>Outline of the parcel in the national grid; null for a bare point.</summary>
    public LocalGeometry? Local { get; init; }
}

/// <summary>A point in a national metric grid: <see cref="X"/> = easting, <see cref="Y"/> = northing, metres.</summary>
public readonly record struct LocalPoint(double X, double Y);

/// <summary>Parcel outline in a national grid (EPSG code <see cref="Srid"/>) and a point surely inside it.</summary>
public sealed record LocalGeometry(int Srid, IReadOnlyList<LocalPoint> Ring, LocalPoint Inside)
{
    /// <summary>Outline with <see cref="Inside"/> computed by <see cref="InteriorPoint"/>.</summary>
    public static LocalGeometry FromRing(int srid, IReadOnlyList<LocalPoint> ring) =>
        new(srid, ring, InteriorPoint(ring));

    /// <summary>Area of the outline, square metres.</summary>
    public double AreaM2 => Math.Abs(SignedArea(Ring));

    /// <summary>Whether the point is inside the outline (even-odd rule).</summary>
    public static bool Contains(IReadOnlyList<LocalPoint> ring, LocalPoint p)
    {
        var inside = false;
        for (int i = 0, j = ring.Count - 1; i < ring.Count; j = i++)
        {
            var (a, b) = (ring[i], ring[j]);
            if ((a.Y > p.Y) != (b.Y > p.Y) && p.X < (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X)
            {
                inside = !inside;
            }
        }

        return inside;
    }

    /// <summary>
    /// A point inside the outline: the centroid when it is inside (most parcels), otherwise the middle of the
    /// widest piece of the horizontal line through the centroid (L- or U-shaped parcels).
    /// </summary>
    public static LocalPoint InteriorPoint(IReadOnlyList<LocalPoint> ring)
    {
        if (ring.Count == 0)
        {
            throw new ArgumentException("Empty outline.", nameof(ring));
        }

        var area = SignedArea(ring);
        LocalPoint centroid;
        if (Math.Abs(area) < 1e-9)
        {
            centroid = new LocalPoint(ring.Average(p => p.X), ring.Average(p => p.Y));
        }
        else
        {
            double cx = 0, cy = 0;
            for (int i = 0, j = ring.Count - 1; i < ring.Count; j = i++)
            {
                var cross = ring[j].X * ring[i].Y - ring[i].X * ring[j].Y;
                cx += (ring[j].X + ring[i].X) * cross;
                cy += (ring[j].Y + ring[i].Y) * cross;
            }

            centroid = new LocalPoint(cx / (6 * area), cy / (6 * area));
        }

        if (Contains(ring, centroid))
        {
            return centroid;
        }

        var xs = new List<double>();
        for (int i = 0, j = ring.Count - 1; i < ring.Count; j = i++)
        {
            var (a, b) = (ring[i], ring[j]);
            if ((a.Y > centroid.Y) != (b.Y > centroid.Y))
            {
                xs.Add(a.X + (centroid.Y - a.Y) * (b.X - a.X) / (b.Y - a.Y));
            }
        }

        xs.Sort();
        var best = ring[0];
        var widest = -1.0;
        for (var k = 0; k + 1 < xs.Count; k += 2)
        {
            if (xs[k + 1] - xs[k] > widest)
            {
                widest = xs[k + 1] - xs[k];
                best = new LocalPoint((xs[k] + xs[k + 1]) / 2, centroid.Y);
            }
        }

        return best;
    }

    private static double SignedArea(IReadOnlyList<LocalPoint> ring)
    {
        double sum = 0;
        for (int i = 0, j = ring.Count - 1; i < ring.Count; j = i++)
        {
            sum += ring[j].X * ring[i].Y - ring[i].X * ring[j].Y;
        }

        return sum / 2;
    }
}

/// <summary>What every field data provider has, whatever data it gives.</summary>
public interface IFieldDataSource
{
    /// <summary>Stable id, also the cache namespace; change its version suffix when the result shape changes.</summary>
    string Id { get; }

    /// <summary>Whether this source has data for the location (country, needs a parcel, ...).</summary>
    bool Supports(FieldLocation location);
}

/// <summary>
/// A source of one kind of field data. One implementation per source (and so per country, where the data is
/// national); the first one whose <see cref="IFieldDataSource.Supports"/> says yes answers. Adding a country = new
/// implementations registered in DI, no change in the services that use them.
/// <para>Results are cached in PostgreSQL by <c>FieldDataCache</c> under <see cref="IFieldDataSource.Id"/> and
/// <see cref="CacheKey"/>, so <typeparamref name="T"/> must round-trip through System.Text.Json.</para>
/// </summary>
public interface IFieldDataProvider<T> : IFieldDataSource where T : class
{
    /// <summary>How long a result stays valid.</summary>
    TimeSpan CacheFor { get; }

    /// <summary>How long "no data here" is remembered (short: the source may get the data later).</summary>
    TimeSpan MissingCacheFor => TimeSpan.FromDays(1);

    /// <summary>Key of the location for this source, e.g. the parcel id or a rounded point.</summary>
    string CacheKey(FieldLocation location);

    /// <summary>The data; null when the source has none for the location. Throws when the source fails.</summary>
    Task<T?> GetAsync(FieldLocation location, CancellationToken ct);
}

/// <summary>Soil composition by depth (sand, clay, pH, ...) at a point: modelled, worldwide.</summary>
public interface ISoilPropertiesProvider : IFieldDataProvider<SoilGridsData>
{
}

/// <summary>The official land register entry of a parcel: land use and soil quality classes.</summary>
public interface ILandRegistryProvider : IFieldDataProvider<LandRegistryInfo>
{
}

/// <summary>An agricultural soil map at the parcel: suitability complex, soil type, texture.</summary>
public interface ISoilMapProvider : IFieldDataProvider<SoilMapInfo>
{
}

/// <summary>Elevation and slope of a parcel from a terrain model.</summary>
public interface ITerrainProvider : IFieldDataProvider<TerrainInfo>
{
}

/// <summary>Land register entry of a parcel.</summary>
public sealed record LandRegistryInfo
{
    /// <summary>Data source (Polish), shown to the user.</summary>
    public required string Source { get; init; }

    /// <summary>Area in the register, hectares.</summary>
    public double? AreaHa { get; init; }

    /// <summary>Region names from the register (Poland: voivodeship, county, commune, precinct).</summary>
    public IReadOnlyList<string> Place { get; init; } = [];

    /// <summary>Land use / soil quality classes on the parcel, in the register's order.</summary>
    public IReadOnlyList<LandClass> Classes { get; init; } = [];

    /// <summary>When the register data was published.</summary>
    public DateOnly? PublishedOn { get; init; }
}

/// <summary>One land class of a parcel, e.g. "RIVb" = arable land, soil quality class IVb.</summary>
public sealed record LandClass
{
    /// <summary>The register's code, as written there.</summary>
    public required string Code { get; init; }

    /// <summary>Land use in plain words (Polish), e.g. "grunty orne".</summary>
    public required string LandUse { get; init; }

    /// <summary>Soil quality class, e.g. "IVb"; null for land without one (roads, buildings, ...).</summary>
    public string? QualityClass { get; init; }

    /// <summary>Official name of the quality class (Polish), e.g. "średnie gorsze".</summary>
    public string? QualityName { get; init; }
}

/// <summary>Agricultural soil map at a point of the parcel.</summary>
public sealed record SoilMapInfo
{
    /// <summary>Data source (Polish).</summary>
    public required string Source { get; init; }

    /// <summary>Code of the agricultural suitability complex, e.g. "5".</summary>
    public string? ComplexCode { get; init; }

    /// <summary>Name of the complex (Polish), e.g. "kompleks żytni dobry".</summary>
    public string? ComplexName { get; init; }

    /// <summary>Soil type code, e.g. "A".</summary>
    public string? SoilTypeCode { get; init; }

    /// <summary>Soil type name (Polish), e.g. "gleby bielicowe i pseudobielicowe".</summary>
    public string? SoilTypeName { get; init; }

    /// <summary>Texture from the surface down, e.g. "piaski gliniaste lekkie" then "gliny średnie" at 50–100 cm.</summary>
    public IReadOnlyList<SoilTexture> Texture { get; init; } = [];

    /// <summary>When the soil survey was made (many are from the 1960s–70s).</summary>
    public DateOnly? SurveyedOn { get; init; }
}

/// <summary>One texture layer of the soil map.</summary>
public sealed record SoilTexture
{
    /// <summary>The map's code, e.g. "pgl".</summary>
    public required string Code { get; init; }

    /// <summary>Plain name (Polish), e.g. "piaski gliniaste lekkie"; the code itself when unknown.</summary>
    public required string Name { get; init; }

    /// <summary>Depth where this layer starts (Polish), e.g. "50–100 cm"; null for the top layer.</summary>
    public string? From { get; init; }
}

/// <summary>Elevation and slope of a parcel.</summary>
public sealed record TerrainInfo
{
    /// <summary>Data source (Polish).</summary>
    public required string Source { get; init; }

    /// <summary>Lowest, mean and highest sampled elevation, metres above sea level.</summary>
    public required double ElevationMinM { get; init; }

    /// <inheritdoc cref="ElevationMinM"/>
    public required double ElevationMeanM { get; init; }

    /// <inheritdoc cref="ElevationMinM"/>
    public required double ElevationMaxM { get; init; }

    /// <summary>Mean slope of the parcel (plane fitted to the samples), %.</summary>
    public required double SlopePct { get; init; }

    /// <summary>Slope class (Polish), as in the map layers: "płasko", "łagodny spadek", "umiarkowany spadek", "stromo".</summary>
    public required string SlopeClass { get; init; }

    /// <summary>Number of sampled points.</summary>
    public required int Samples { get; init; }
}
