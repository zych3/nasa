using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.FieldData.Cache;

/// <summary>A cached provider answer: JSON (null = "no data here") and when it was fetched.</summary>
public sealed record CachedValue(string? Json, DateTimeOffset FetchedAt);

/// <summary>Storage of provider answers. Never throws for storage problems: the data is then just not cached.</summary>
public interface IProviderCache
{
    /// <summary>The stored answer if it has not expired at <paramref name="now"/>; null otherwise.</summary>
    Task<CachedValue?> GetAsync(string provider, string key, DateTimeOffset now, CancellationToken ct);

    Task SetAsync(
        string provider, string key, string? json, DateTimeOffset fetchedAt, DateTimeOffset expiresAt,
        CancellationToken ct);
}

/// <summary>
/// <see cref="IProviderCache"/> in the <c>provider_cache</c> table. When the database fails it is skipped for
/// <see cref="OfflineFor"/>, so requests do not each wait for a connection timeout while it is down.
/// </summary>
public sealed class PostgresProviderCache(
    IDbContextFactory<FieldDataDbContext> factory,
    FieldDataSchema schema,
    TimeProvider time,
    ILogger<PostgresProviderCache> logger) : IProviderCache
{
    public static readonly TimeSpan OfflineFor = TimeSpan.FromMinutes(1);

    private long _offlineUntilTicks;

    private bool IsOffline => time.GetUtcNow().UtcTicks < Interlocked.Read(ref _offlineUntilTicks);

    public async Task<CachedValue?> GetAsync(string provider, string key, DateTimeOffset now, CancellationToken ct)
    {
        if (IsOffline)
        {
            return null;
        }

        try
        {
            await schema.EnsureAppliedAsync(ct);
            await using var db = await factory.CreateDbContextAsync(ct);
            var entry = await db.Entries.AsNoTracking()
                .Where(e => e.Provider == provider && e.Key == key && e.ExpiresAt > now)
                .Select(e => new CachedValue(e.Payload, e.FetchedAt))
                .FirstOrDefaultAsync(ct);
            return entry;
        }
        catch (Exception ex) when (FieldDataDbContext.IsDatabaseFailure(ex))
        {
            GoOffline(ex);
            return null;
        }
    }

    public async Task SetAsync(
        string provider, string key, string? json, DateTimeOffset fetchedAt, DateTimeOffset expiresAt,
        CancellationToken ct)
    {
        if (IsOffline)
        {
            return;
        }

        try
        {
            await schema.EnsureAppliedAsync(ct);
            await using var db = await factory.CreateDbContextAsync(ct);
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO provider_cache (provider, key, payload, fetched_at, expires_at)
                VALUES ({provider}, {key}, CAST({json} AS jsonb), {fetchedAt}, {expiresAt})
                ON CONFLICT (provider, key) DO UPDATE
                SET payload = EXCLUDED.payload, fetched_at = EXCLUDED.fetched_at, expires_at = EXCLUDED.expires_at
                """, ct);
        }
        catch (Exception ex) when (FieldDataDbContext.IsDatabaseFailure(ex))
        {
            GoOffline(ex);
        }
    }

    private void GoOffline(Exception ex)
    {
        logger.LogWarning(ex, "Field data cache unavailable; skipping it for {Minutes} min", OfflineFor.TotalMinutes);
        Interlocked.Exchange(ref _offlineUntilTicks, (time.GetUtcNow() + OfflineFor).UtcTicks);
    }
}
