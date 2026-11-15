using FieldShift.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

/// <summary>One registered user (table <c>users</c>).</summary>
public sealed class User
{
    public Guid Id { get; set; }

    /// <summary>Login, stored trimmed and lower case; unique.</summary>
    public required string Email { get; set; }

    /// <summary>ASP.NET Core Identity password hash (PBKDF2, salted); never the password itself.</summary>
    public required string PasswordHash { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public List<UserSession> Sessions { get; } = [];
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
/// history table <see cref="MigrationsHistoryTable"/>). Saved rotation queries and crop alerts will hang off
/// <see cref="User"/>.
/// </summary>
public sealed class AccountsDbContext(DbContextOptions<AccountsDbContext> options) : DbContext(options)
{
    public const string MigrationsHistoryTable = "__accounts_migrations";

    public DbSet<User> Users => Set<User>();

    public DbSet<UserSession> Sessions => Set<UserSession>();

    /// <summary>The database is down or rejected the command (same rule as the price cache).</summary>
    public static bool IsDatabaseFailure(Exception e) => PricesDbContext.IsDatabaseFailure(e);

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<User>(e =>
        {
            e.ToTable("users");
            e.HasKey(u => u.Id);
            e.Property(u => u.Id).HasColumnName("id");
            e.Property(u => u.Email).HasColumnName("email").HasColumnType("text");
            e.Property(u => u.PasswordHash).HasColumnName("password_hash").HasColumnType("text");
            e.Property(u => u.CreatedAt).HasColumnName("created_at");
            e.HasIndex(u => u.Email).IsUnique();
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