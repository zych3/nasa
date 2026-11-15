using FieldShift.Web.Data;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

/// <summary>A user account. The e-mail is stored lower-case and is unique.</summary>
public sealed class UserAccount
{
    public Guid Id { get; set; }

    public required string Email { get; set; }

    /// <summary>Name shown in the app (optional).</summary>
    public string? Name { get; set; }

    /// <summary>ASP.NET Core Identity password hash (PBKDF2, salted).</summary>
    public required string PasswordHash { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>
/// A signed-in device. Only the SHA-256 of the token is stored, so a leaked table does not let anyone sign in.
/// </summary>
public sealed class UserSession
{
    public required string TokenHash { get; set; }

    public Guid UserId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }
}

/// <summary>
/// User accounts in PostgreSQL (the same database as the prices, its own migrations: Migrations/Accounts,
/// history table <see cref="MigrationsHistoryTable"/>).
/// </summary>
public sealed class AccountsDbContext(DbContextOptions<AccountsDbContext> options) : DbContext(options)
{
    public const string MigrationsHistoryTable = "__accounts_migrations";

    public DbSet<UserAccount> Users => Set<UserAccount>();

    public DbSet<UserSession> Sessions => Set<UserSession>();

    /// <summary>The database is down or rejected the command (same rule as the price cache).</summary>
    public static bool IsDatabaseFailure(Exception e) => PricesDbContext.IsDatabaseFailure(e);

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<UserAccount>(e =>
        {
            e.ToTable("user_accounts");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.Email).HasColumnName("email").HasColumnType("text");
            e.Property(x => x.Name).HasColumnName("name").HasColumnType("text");
            e.Property(x => x.PasswordHash).HasColumnName("password_hash").HasColumnType("text");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.HasIndex(x => x.Email).IsUnique();
        });

        model.Entity<UserSession>(e =>
        {
            e.ToTable("user_sessions");
            e.HasKey(x => x.TokenHash);
            e.Property(x => x.TokenHash).HasColumnName("token_hash").HasColumnType("text");
            e.Property(x => x.UserId).HasColumnName("user_id");
            e.Property(x => x.CreatedAt).HasColumnName("created_at");
            e.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            e.HasOne<UserAccount>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.UserId);
        });
    }
}

/// <summary>Applies the account migrations once, on first use (like <see cref="PricesSchema"/>).</summary>
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
