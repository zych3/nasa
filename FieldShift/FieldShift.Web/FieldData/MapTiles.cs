using FieldShift.Web.FieldData.Cache;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.FieldData;

/// <summary>One entry of a map layer's legend: the source's code, its name and the colour the map uses.</summary>
public sealed record MapLegendItem(string Code, string Name, string Color);

/// <summary>
/// A map layer drawn as web map tiles (256 px, Web Mercator / EPSG:3857, z/x/y like OpenStreetMap), e.g. the soil
/// map. Several countries can serve the same <see cref="LayerId"/>: each covers its own area, and the first one
/// covering a tile draws it. The app asks only our backend (<c>/api/map-tiles</c>), never the source.
/// </summary>
public interface IMapTileProvider
{
    /// <summary>Layer id in the URL, e.g. "soil-map".</summary>
    string LayerId { get; }

    /// <summary>Zoom levels with a useful picture (the source draws nothing further out).</summary>
    int MinZoom { get; }

    int MaxZoom { get; }

    /// <summary>How long a tile is kept in the cache.</summary>
    TimeSpan CacheFor { get; }

    /// <summary>What the colours mean, in the source's words.</summary>
    IReadOnlyList<MapLegendItem> Legend { get; }

    /// <summary>Whether the tile lies (at least partly) in the area this provider has data for.</summary>
    bool Covers(TileAddress tile);

    /// <summary>The tile as PNG. Throws when the source fails.</summary>
    Task<byte[]> GetTileAsync(TileAddress tile, CancellationToken ct);
}

/// <summary>A web map tile: zoom, column (west → east), row (north → south).</summary>
public readonly record struct TileAddress(int Z, int X, int Y)
{
    private const double HalfWorld = 20037508.342789244;

    public bool IsValid => Z is >= 0 and <= 22 && X >= 0 && Y >= 0 && X < 1L << Z && Y < 1L << Z;

    /// <summary>Edges in EPSG:3857 metres: west, south, east, north.</summary>
    public (double West, double South, double East, double North) MercatorBounds
    {
        get
        {
            var size = 2 * HalfWorld / (1L << Z);
            return (-HalfWorld + X * size, HalfWorld - (Y + 1) * size, -HalfWorld + (X + 1) * size, HalfWorld - Y * size);
        }
    }

    /// <summary>Edges in degrees: west, south, east, north.</summary>
    public (double West, double South, double East, double North) Bounds
    {
        get
        {
            var (w, s, e, n) = MercatorBounds;
            return (w / HalfWorld * 180, Latitude(s), e / HalfWorld * 180, Latitude(n));
        }
    }

    private static double Latitude(double y) =>
        (2 * Math.Atan(Math.Exp(y / HalfWorld * Math.PI)) - Math.PI / 2) * 180 / Math.PI;
}

/// <summary>
/// Map tiles through a PostgreSQL cache (<c>tile_cache</c>): a stored tile is served without asking the source.
/// Tiles outside every provider's area, at zooms without a picture, and of a failing source are a transparent
/// tile (not stored), so the map simply shows nothing there.
/// </summary>
public sealed class MapTileService(
    IEnumerable<IMapTileProvider> providers,
    IDbContextFactory<FieldDataDbContext> db,
    FieldDataSchema schema,
    TimeProvider time,
    ILogger<MapTileService> logger)
{
    /// <summary>A 1 × 1 transparent PNG.</summary>
    public static readonly byte[] Empty = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNgYGBgAAAABQABeqhXUAAAAABJRU5ErkJggg==");

    private static readonly TimeSpan OfflineFor = TimeSpan.FromMinutes(1);
    private long _offlineUntilTicks;

    /// <summary>The legend of a layer (from its first provider); null for an unknown layer.</summary>
    public IReadOnlyList<MapLegendItem>? Legend(string layerId) =>
        providers.FirstOrDefault(p => p.LayerId == layerId)?.Legend;

    public bool HasLayer(string layerId) => providers.Any(p => p.LayerId == layerId);

    /// <summary>The tile's PNG; <see cref="Empty"/> where there is nothing to draw.</summary>
    public async Task<byte[]> GetAsync(string layerId, TileAddress tile, CancellationToken ct)
    {
        var provider = providers.FirstOrDefault(p =>
            p.LayerId == layerId && tile.Z >= p.MinZoom && tile.Z <= p.MaxZoom && p.Covers(tile));
        if (provider is null)
        {
            return Empty;
        }

        if (await ReadAsync(layerId, tile, ct) is { } cached)
        {
            return cached;
        }

        byte[] png;
        try
        {
            png = await provider.GetTileAsync(tile, ct);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            logger.LogWarning(ex, "Tile {Layer} {Z}/{X}/{Y} failed", layerId, tile.Z, tile.X, tile.Y);
            return Empty;
        }

        await WriteAsync(layerId, tile, png, provider.CacheFor, ct);
        return png;
    }

    private bool IsOffline => time.GetUtcNow().UtcTicks < Interlocked.Read(ref _offlineUntilTicks);

    private async Task<byte[]?> ReadAsync(string layerId, TileAddress tile, CancellationToken ct)
    {
        if (IsOffline)
        {
            return null;
        }

        try
        {
            await schema.EnsureAppliedAsync(ct);
            await using var context = await db.CreateDbContextAsync(ct);
            var now = time.GetUtcNow();
            return await context.Tiles.AsNoTracking()
                .Where(t => t.Layer == layerId && t.Z == tile.Z && t.X == tile.X && t.Y == tile.Y && t.ExpiresAt > now)
                .Select(t => t.Png)
                .FirstOrDefaultAsync(ct);
        }
        catch (Exception ex) when (FieldDataDbContext.IsDatabaseFailure(ex))
        {
            GoOffline(ex);
            return null;
        }
    }

    private async Task WriteAsync(string layerId, TileAddress tile, byte[] png, TimeSpan ttl, CancellationToken ct)
    {
        if (IsOffline)
        {
            return;
        }

        try
        {
            await schema.EnsureAppliedAsync(ct);
            await using var context = await db.CreateDbContextAsync(ct);
            var now = time.GetUtcNow();
            var expires = now + ttl;
            await context.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO tile_cache (layer, z, x, y, png, fetched_at, expires_at)
                VALUES ({layerId}, {tile.Z}, {tile.X}, {tile.Y}, {png}, {now}, {expires})
                ON CONFLICT (layer, z, x, y) DO UPDATE
                SET png = EXCLUDED.png, fetched_at = EXCLUDED.fetched_at, expires_at = EXCLUDED.expires_at
                """, ct);
        }
        catch (Exception ex) when (FieldDataDbContext.IsDatabaseFailure(ex))
        {
            GoOffline(ex);
        }
    }

    private void GoOffline(Exception ex)
    {
        logger.LogWarning(ex, "Tile cache unavailable; skipping it for {Minutes} min", OfflineFor.TotalMinutes);
        Interlocked.Exchange(ref _offlineUntilTicks, (time.GetUtcNow() + OfflineFor).UtcTicks);
    }
}
