using FieldShift.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

/// <summary>One registered user (table <c>users</c>).</summary>
public sealed class User
{
    public Guid Id { get; set; }

    /// <summary>Login name, stored trimmed and lower case; unique.</summary>
    public required string Username { get; set; }

    /// <summary>ASP.NET Core Identity password hash (PBKDF2, salted); never the password itself.</summary>
    public required string PasswordHash { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public List<UserSession> Sessions { get; } = [];

    public List<UserCrop> Crops { get; } = [];

    public List<SavedPlan> SavedPlans { get; } = [];

    public List<SavedParcel> SavedParcels { get; } = [];
}

/// <summary>
/// A rotation plan the user chose to keep (table <c>saved_plans</c>): the plan exactly as the recommendations
/// endpoint returned it, plus the answers it was made from, so it can be shown again without recalculating.
/// </summary>
public sealed class SavedPlan
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public User? User { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public string? ParcelId { get; set; }

    public double Lat { get; set; }

    public double Lon { get; set; }

    /// <summary>"balanced", "soil_health" or "safe_harvest".</summary>
    public required string Goal { get; set; }

    /// <summary>The chosen plan (one element of <c>recommendations[].best</c> or <c>.alternatives</c>), as JSON.</summary>
    public required string PlanJson { get; set; }

    /// <summary>What the farmer answered (past crops, exclusions, ...), as JSON; null when not sent.</summary>
    public string? AnswersJson { get; set; }
}

/// <summary>
/// One parcel of the user's "My parcels" list (table <c>saved_parcels</c>), a backup of what their devices keep.
/// A removed parcel stays as a marker (<see cref="IsDeleted"/>) for a while so other devices remove it too.
/// </summary>
public sealed class SavedParcel
{
    public Guid UserId { get; set; }

    public User? User { get; set; }

    /// <summary>The parcel's id from the land register lookup.</summary>
    public required string ParcelId { get; set; }

    /// <summary>The parcel object as the app keeps it (id, centre, outline, address), as JSON.</summary>
    public required string DataJson { get; set; }

    /// <summary>When the user last added or removed it, as set by the app; the newer change wins.</summary>
    public DateTimeOffset UpdatedAt { get; set; }

    public bool IsDeleted { get; set; }
}

/// <summary>
/// One crop the user grows at one place (table <c>user_crops</c>), saved so that later the app can check whether
/// it is at risk. <see cref="IsActive"/> = the user wants it watched; inactive entries are kept but skipped.
/// </summary>
public sealed class UserCrop
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public User? User { get; set; }

    /// <summary>e.g. "wheat"; matches <c>CropCatalog</c>. Not a foreign key: the catalogue lives in code.</summary>
    public required string CropId { get; set; }

    public double Latitude { get; set; }

    public double Longitude { get; set; }

    /// <summary>The registered parcel at the place, when one was chosen.</summary>
    public string? ParcelId { get; set; }

    /// <summary>The user's words for the place, e.g. the address or "field by the river".</summary>
    public string? Label { get; set; }

    public bool IsActive { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>
/// One logged-in device (table <c>user_sessions</c>). The client keeps the token; only its SHA-256 hash is stored,
/// so a leaked database does not let anyone log in. Logout deletes the row.
/// </summary>
public sealed class UserSession
{
    /// <summary>SHA-256 of the token, hex.</summary>
    public required string TokenHash { get; set; }

    public Guid UserId { get; set; }

    public User? User { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }
}

/// <summary>
/// Users and their sessions in PostgreSQL (the same database as the prices, own migrations: Migrations/Accounts,
/// history table <see cref="MigrationsHistoryTable"/>). Also the user's crops (<see cref="UserCrop"/>).
/// </summary>
public sealed class AccountsDbContext(DbContextOptions<AccountsDbContext> options) : DbContext(options)
{
    public const string MigrationsHistoryTable = "__accounts_migrations";

    public DbSet<User> Users => Set<User>();

    public DbSet<UserSession> Sessions => Set<UserSession>();

    public DbSet<UserCrop> Crops => Set<UserCrop>();

    public DbSet<SavedPlan> SavedPlans => Set<SavedPlan>();

    public DbSet<SavedParcel> SavedParcels => Set<SavedParcel>();

    /// <summary>The database is down or rejected the command (same rule as the price cache).</summary>
    public static bool IsDatabaseFailure(Exception e) => DatabaseErrors.IsDatabaseFailure(e);

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<User>(e =>
        {
            e.ToTable("users");
            e.HasKey(u => u.Id);
            e.Property(u => u.Id).HasColumnName("id");
            e.Property(u => u.Username).HasColumnName("username").HasColumnType("text");
            e.Property(u => u.PasswordHash).HasColumnName("password_hash").HasColumnType("text");
            e.Property(u => u.CreatedAt).HasColumnName("created_at");
            e.HasIndex(u => u.Username).IsUnique();
        });

        model.Entity<UserSession>(e =>
        {
            e.ToTable("user_sessions");
            e.HasKey(s => s.TokenHash);
            e.Property(s => s.TokenHash).HasColumnName("token_hash").HasColumnType("char(64)");
            e.Property(s => s.UserId).HasColumnName("user_id");
            e.Property(s => s.CreatedAt).HasColumnName("created_at");
            e.Property(s => s.ExpiresAt).HasColumnName("expires_at");
            e.HasOne(s => s.User).WithMany(u => u.Sessions).HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(s => s.UserId);
            e.HasIndex(s => s.ExpiresAt);
        });

        model.Entity<UserCrop>(e =>
        {
            e.ToTable("user_crops");
            e.HasKey(c => c.Id);
            e.Property(c => c.Id).HasColumnName("id");
            e.Property(c => c.UserId).HasColumnName("user_id");
            e.Property(c => c.CropId).HasColumnName("crop_id").HasColumnType("text");
            e.Property(c => c.Latitude).HasColumnName("latitude");
            e.Property(c => c.Longitude).HasColumnName("longitude");
            e.Property(c => c.ParcelId).HasColumnName("parcel_id").HasColumnType("text");
            e.Property(c => c.Label).HasColumnName("label").HasColumnType("text");
            e.Property(c => c.IsActive).HasColumnName("is_active");
            e.Property(c => c.CreatedAt).HasColumnName("created_at");
            e.Property(c => c.UpdatedAt).HasColumnName("updated_at");
            e.HasOne(c => c.User).WithMany(u => u.Crops).HasForeignKey(c => c.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(c => c.UserId);
            // Later: the risk check reads all active entries.
            e.HasIndex(c => c.IsActive);
        });

        model.Entity<SavedPlan>(e =>
        {
            e.ToTable("saved_plans");
            e.HasKey(p => p.Id);
            e.Property(p => p.Id).HasColumnName("id");
            e.Property(p => p.UserId).HasColumnName("user_id");
            e.Property(p => p.CreatedAt).HasColumnName("created_at");
            e.Property(p => p.ParcelId).HasColumnName("parcel_id").HasColumnType("text");
            e.Property(p => p.Lat).HasColumnName("lat");
            e.Property(p => p.Lon).HasColumnName("lon");
            e.Property(p => p.Goal).HasColumnName("goal").HasColumnType("text");
            e.Property(p => p.PlanJson).HasColumnName("plan").HasColumnType("jsonb");
            e.Property(p => p.AnswersJson).HasColumnName("answers").HasColumnType("jsonb");
            e.HasOne(p => p.User).WithMany(u => u.SavedPlans).HasForeignKey(p => p.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(p => new { p.UserId, p.CreatedAt });
        });

        model.Entity<SavedParcel>(e =>
        {
            e.ToTable("saved_parcels");
            e.HasKey(p => new { p.UserId, p.ParcelId });
            e.Property(p => p.UserId).HasColumnName("user_id");
            e.Property(p => p.ParcelId).HasColumnName("parcel_id").HasColumnType("text");
            e.Property(p => p.DataJson).HasColumnName("data").HasColumnType("jsonb");
            e.Property(p => p.UpdatedAt).HasColumnName("updated_at");
            e.Property(p => p.IsDeleted).HasColumnName("is_deleted");
            e.HasOne(p => p.User).WithMany(u => u.SavedParcels).HasForeignKey(p => p.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}

/// <summary>
/// Applies the accounts migrations once per process, before the first use (same pattern as the other schemas).
/// A failed attempt (database down) is retried on the next call.
/// </summary>
public sealed class AccountsSchema(IDbContextFactory<AccountsDbContext> factory)
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