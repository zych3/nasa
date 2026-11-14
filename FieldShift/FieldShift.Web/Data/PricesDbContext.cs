using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FieldShift.Web.Data;

/// <summary>
/// One external price source (table <c>price_sources</c>). Staleness is tracked per source, because a
/// source is fetched as one batch for all crops (GUS allows 100 requests / 15 min).
/// </summary>
public sealed class PriceSource
{
    /// <summary>e.g. "gus_bdl".</summary>
    public required string Id { get; set; }

    /// <summary>ISO 3166-1 alpha-2, e.g. "PL".</summary>
    public required string Country { get; set; }

    /// <summary>Last time the API was called.</summary>
    public DateTimeOffset? LastAttemptAt { get; set; }

    /// <summary>Last time the API answered; decides whether the stored prices are stale.</summary>
    public DateTimeOffset? LastSuccessAt { get; set; }

    /// <summary>Error of the last attempt; null after a success.</summary>
    public string? LastError { get; set; }

    public List<PriceSeries> Series { get; } = [];
}

/// <summary>
/// Prices of one crop from one source (table <c>price_series</c>). A crop with no row after a
/// successful sync has "no data".
/// </summary>
public sealed class PriceSeries
{
    public const string Weekly = "weekly";
    public const string Monthly = "monthly";
    public const string Yearly = "yearly";

    public int Id { get; set; }

    public required string SourceId { get; set; }

    public PriceSource? Source { get; set; }

    /// <summary>e.g. "wheat"; matches <c>CropCatalog</c>. Not a foreign key: the catalogue lives in code.</summary>
    public required string CropId { get; set; }

    /// <summary><see cref="Weekly"/>, <see cref="Monthly"/> or <see cref="Yearly"/>.</summary>
    public required string Frequency { get; set; }

    /// <summary>e.g. "PLN".</summary>
    public required string Currency { get; set; }

    /// <summary>Unit the price is for, e.g. "t".</summary>
    public required string Unit { get; set; }

    /// <summary>e.g. "GUS BDL P2967: ...".</summary>
    public required string SourceName { get; set; }

    /// <summary>e.g. "one_price_all_barley"; translated by the frontend.</summary>
    public string? NoteCode { get; set; }

    public List<PricePoint> Points { get; } = [];
}

/// <summary>One price (table <c>price_points</c>). Full history is kept; a re-sync overwrites revised values.</summary>
public sealed class PricePoint
{
    public int SeriesId { get; set; }

    /// <summary>First day of the week, month or year.</summary>
    public DateOnly PeriodStart { get; set; }

    /// <summary>Per <see cref="PriceSeries.Unit"/>, e.g. PLN per tonne.</summary>
    public decimal Price { get; set; }
}

/// <summary>
/// Applies the EF migrations once per process, before the first use of the database. Registered as a
/// singleton. Callers wait for a migration that is in progress instead of hitting missing tables, and
/// a failed attempt (database down) is retried on the next call.
/// </summary>
public sealed class PricesSchema(IServiceScopeFactory scopes)
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

            using var scope = scopes.CreateScope();
            await scope.ServiceProvider.GetRequiredService<PricesDbContext>().Database.MigrateAsync(ct);
            _applied = true;
        }
        finally
        {
            _lock.Release();
        }
    }
}

/// <summary>
/// Price cache in PostgreSQL. The schema comes from the EF migrations in <c>Migrations/</c>
/// (add one with <c>dotnet ef migrations add Name</c>); <see cref="PricesSchema"/> applies them.
/// </summary>
public sealed class PricesDbContext(DbContextOptions<PricesDbContext> options) : DbContext(options)
{
    public DbSet<PriceSource> Sources => Set<PriceSource>();
    public DbSet<PriceSeries> Series => Set<PriceSeries>();
    public DbSet<PricePoint> Points => Set<PricePoint>();

    /// <summary>True when <paramref name="e"/> means the database is down or rejected the command.</summary>
    public static bool IsDatabaseFailure(Exception e) =>
        e is NpgsqlException or DbUpdateException or TimeoutException
        || (e is InvalidOperationException && e.InnerException is NpgsqlException);

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<PriceSource>(e =>
        {
            e.ToTable("price_sources");
            e.HasKey(s => s.Id);
            e.Property(s => s.Id).HasColumnName("id").HasColumnType("text");
            e.Property(s => s.Country).HasColumnName("country").HasColumnType("char(2)");
            e.Property(s => s.LastAttemptAt).HasColumnName("last_attempt_at");
            e.Property(s => s.LastSuccessAt).HasColumnName("last_success_at");
            e.Property(s => s.LastError).HasColumnName("last_error").HasColumnType("text");
        });

        model.Entity<PriceSeries>(e =>
        {
            e.ToTable("price_series", t => t.HasCheckConstraint(
                "ck_price_series_frequency",
                $"frequency IN ('{PriceSeries.Weekly}', '{PriceSeries.Monthly}', '{PriceSeries.Yearly}')"));
            e.HasKey(s => s.Id);
            e.Property(s => s.Id).HasColumnName("id");
            e.Property(s => s.SourceId).HasColumnName("source_id").HasColumnType("text");
            e.Property(s => s.CropId).HasColumnName("crop_id").HasColumnType("text");
            e.Property(s => s.Frequency).HasColumnName("frequency").HasColumnType("text");
            e.Property(s => s.Currency).HasColumnName("currency").HasColumnType("char(3)");
            e.Property(s => s.Unit).HasColumnName("unit").HasColumnType("text");
            e.Property(s => s.SourceName).HasColumnName("source_name").HasColumnType("text");
            e.Property(s => s.NoteCode).HasColumnName("note_code").HasColumnType("text");
            e.HasOne(s => s.Source).WithMany(s => s.Series).HasForeignKey(s => s.SourceId)
                .OnDelete(DeleteBehavior.Restrict);
            e.HasIndex(s => new { s.SourceId, s.CropId }).IsUnique();
            e.HasIndex(s => s.CropId);
        });

        model.Entity<PricePoint>(e =>
        {
            e.ToTable("price_points");
            e.HasKey(p => new { p.SeriesId, p.PeriodStart });
            e.Property(p => p.SeriesId).HasColumnName("series_id");
            e.Property(p => p.PeriodStart).HasColumnName("period_start");
            e.Property(p => p.Price).HasColumnName("price").HasColumnType("numeric(12,2)");
            e.HasOne<PriceSeries>().WithMany(s => s.Points).HasForeignKey(p => p.SeriesId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
