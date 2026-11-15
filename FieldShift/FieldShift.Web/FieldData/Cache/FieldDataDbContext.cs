using FieldShift.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.FieldData.Cache;

/// <summary>
/// One cached answer of a field data provider (<see cref="IFieldDataProvider{T}"/>): the result as JSON, or null
/// for "the source has no data here". Rows past <see cref="ExpiresAt"/> are ignored and overwritten.
/// </summary>
public sealed class ProviderCacheEntry
{
    /// <summary>Provider id, e.g. "pl.egib.v1".</summary>
    public required string Provider { get; set; }

    /// <summary>The provider's key for the location, e.g. a parcel id.</summary>
    public required string Key { get; set; }

    /// <summary>The result as JSON; null = the source had no data for the location.</summary>
    public string? Payload { get; set; }

    public DateTimeOffset FetchedAt { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }
}

/// <summary>
/// Field data cache in PostgreSQL (the same database as the prices, its own migrations: Migrations/FieldData,
/// history table <see cref="MigrationsHistoryTable"/>).
/// </summary>
public sealed class FieldDataDbContext(DbContextOptions<FieldDataDbContext> options) : DbContext(options)
{
    public const string MigrationsHistoryTable = "__field_data_migrations";

    public DbSet<ProviderCacheEntry> Entries => Set<ProviderCacheEntry>();

    /// <summary>The database is down or rejected the command (same rule as the price cache).</summary>
    public static bool IsDatabaseFailure(Exception e) => PricesDbContext.IsDatabaseFailure(e);

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<ProviderCacheEntry>(e =>
        {
            e.ToTable("provider_cache");
            e.HasKey(x => new { x.Provider, x.Key });
            e.Property(x => x.Provider).HasColumnName("provider").HasColumnType("text");
            e.Property(x => x.Key).HasColumnName("key").HasColumnType("text");
            e.Property(x => x.Payload).HasColumnName("payload").HasColumnType("jsonb");
            e.Property(x => x.FetchedAt).HasColumnName("fetched_at");
            e.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            e.HasIndex(x => x.ExpiresAt);
        });
    }
}

/// <summary>Applies the field data migrations once, on first use (like <see cref="PricesSchema"/>).</summary>
public sealed class FieldDataSchema(IDbContextFactory<FieldDataDbContext> factory)
{
    private readonly SemaphoreSlim _lock = new(1, 1);
    private volatile bool _applied;

    public async Task EnsureAppliedAsync(CancellationToken ct)
    {
        if (_applied)
        {
            return;
        }

        await _lock.WaitAsync(ct);
        try
        {
            if (_applied)
            {
                return;
            }

            await using var db = await factory.CreateDbContextAsync(ct);
            await db.Database.MigrateAsync(ct);
            _applied = true;
        }
        finally
        {
            _lock.Release();
        }
    }
}
