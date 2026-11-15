using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FieldShift.Web.Accounts;

public sealed class AccountOptions
{
    /// <summary>How long a login stays valid.</summary>
    public int SessionDays { get; set; } = 30;

    /// <summary>
    /// Enables <c>POST /api/auth/test-login</c>: a session for the shared <see cref="AccountService.TestUsername"/>
    /// account without a password. For local testing only; off by default.
    /// </summary>
    public bool TestLogin { get; set; }
}

/// <summary>Error codes sent to the frontend (it translates them; never display text).</summary>
public static class AccountErrorCodes
{
    public const string InvalidUsername = "invalid_username";
    public const string PasswordTooShort = "password_too_short";
    public const string PasswordTooLong = "password_too_long";
    public const string UsernameTaken = "username_taken";
    public const string InvalidCredentials = "invalid_credentials";
    public const string DatabaseUnavailable = "database_unavailable";
}

public sealed record AccountResult(User? User, string? Token, DateTimeOffset? ExpiresAt, string? ErrorCode)
{
    public static AccountResult Fail(string code) => new(null, null, null, code);
}

/// <summary>Registration, login and logout. Passwords are hashed with ASP.NET Core Identity's PBKDF2 hasher.</summary>
public sealed class AccountService(
    IDbContextFactory<AccountsDbContext> contexts,
    AccountsSchema schema,
    IOptions<AccountOptions> options,
    TimeProvider time)
{
    public const int MinUsernameLength = 3;
    public const int MaxUsernameLength = 32;
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 128;

    /// <summary>Account used by the test login. Its password is random, so it cannot be logged into normally.</summary>
    public const string TestUsername = "test";

    private static readonly PasswordHasher<User> Hasher = new();

    /// <summary>Hash checked when the username is unknown, so a wrong username takes as long as a wrong password.</summary>
    private static readonly string DummyHash = Hasher.HashPassword(null!, "not-a-real-password");

    public bool TestLoginEnabled => options.Value.TestLogin;

    public async Task<AccountResult> RegisterAsync(string? username, string? password, CancellationToken ct)
    {
        var normalized = NormalizeUsername(username);
        if (normalized is null)
        {
            return AccountResult.Fail(AccountErrorCodes.InvalidUsername);
        }

        if (password is null || password.Length < MinPasswordLength)
        {
            return AccountResult.Fail(AccountErrorCodes.PasswordTooShort);
        }

        if (password.Length > MaxPasswordLength)
        {
            return AccountResult.Fail(AccountErrorCodes.PasswordTooLong);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        if (await db.Users.AnyAsync(u => u.Username == normalized, ct))
        {
            return AccountResult.Fail(AccountErrorCodes.UsernameTaken);
        }

        var user = NewUser(normalized, password);
        db.Users.Add(user);
        var (token, session) = NewSession(user.Id);
        db.Sessions.Add(session);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (IsUniqueViolation(e))
        {
            // Two registrations with the same username at the same moment.
            return AccountResult.Fail(AccountErrorCodes.UsernameTaken);
        }

        return new AccountResult(user, token, session.ExpiresAt, null);
    }

    public async Task<AccountResult> LoginAsync(string? username, string? password, CancellationToken ct)
    {
        var normalized = NormalizeUsername(username);
        if (normalized is null || string.IsNullOrEmpty(password) || password.Length > MaxPasswordLength)
        {
            return AccountResult.Fail(AccountErrorCodes.InvalidCredentials);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        var user = await db.Users.SingleOrDefaultAsync(u => u.Username == normalized, ct);
        if (user is null)
        {
            Hasher.VerifyHashedPassword(null!, DummyHash, password);
            return AccountResult.Fail(AccountErrorCodes.InvalidCredentials);
        }

        var check = Hasher.VerifyHashedPassword(user, user.PasswordHash, password);
        if (check == PasswordVerificationResult.Failed)
        {
            return AccountResult.Fail(AccountErrorCodes.InvalidCredentials);
        }

        if (check == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = Hasher.HashPassword(user, password);
        }

        return await StartSessionAsync(db, user, ct);
    }

    /// <summary>
    /// A session for the shared test account (created on first use), without a password. Only call when
    /// <see cref="TestLoginEnabled"/>.
    /// </summary>
    public async Task<AccountResult> TestLoginAsync(CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        var user = await db.Users.SingleOrDefaultAsync(u => u.Username == TestUsername, ct);
        if (user is null)
        {
            user = NewUser(TestUsername, Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)));
            db.Users.Add(user);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException e) when (IsUniqueViolation(e))
            {
                // Created by a parallel test login.
                db.ChangeTracker.Clear();
                user = await db.Users.SingleAsync(u => u.Username == TestUsername, ct);
            }
        }

        return await StartSessionAsync(db, user, ct);
    }

    /// <summary>The user the token belongs to, or null when it is unknown or expired.</summary>
    public async Task<User?> FindByTokenAsync(string token, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        var hash = HashToken(token);
        var now = time.GetUtcNow();
        return await db.Sessions
            .Where(s => s.TokenHash == hash && s.ExpiresAt > now)
            .Select(s => s.User)
            .SingleOrDefaultAsync(ct);
    }

    /// <summary>Ends the session of this token (no error when it is already gone).</summary>
    public async Task LogoutAsync(string token, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        var hash = HashToken(token);
        await db.Sessions.Where(s => s.TokenHash == hash).ExecuteDeleteAsync(ct);
    }

    /// <summary>
    /// Trimmed, lower-case username, or null when it is not 3–32 letters, digits, '.', '_' or '-'
    /// (Polish letters allowed).
    /// </summary>
    internal static string? NormalizeUsername(string? username)
    {
        var u = username?.Trim().ToLowerInvariant();
        if (u is null || u.Length is < MinUsernameLength or > MaxUsernameLength)
        {
            return null;
        }

        return u.All(c => char.IsLetterOrDigit(c) || c is '.' or '_' or '-') ? u : null;
    }

    internal static string HashToken(string token) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    private async Task<AccountResult> StartSessionAsync(AccountsDbContext db, User user, CancellationToken ct)
    {
        // Drop this user's expired sessions while we are here.
        var now = time.GetUtcNow();
        await db.Sessions.Where(s => s.UserId == user.Id && s.ExpiresAt <= now).ExecuteDeleteAsync(ct);

        var (token, session) = NewSession(user.Id);
        db.Sessions.Add(session);
        await db.SaveChangesAsync(ct);

        return new AccountResult(user, token, session.ExpiresAt, null);
    }

    private User NewUser(string username, string password)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = username,
            PasswordHash = "",
            CreatedAt = time.GetUtcNow(),
        };
        user.PasswordHash = Hasher.HashPassword(user, password);
        return user;
    }

    private (string Token, UserSession Session) NewSession(Guid userId)
    {
        var token = Base64UrlEncode(RandomNumberGenerator.GetBytes(32));
        var now = time.GetUtcNow();
        return (token, new UserSession
        {
            TokenHash = HashToken(token),
            UserId = userId,
            CreatedAt = now,
            ExpiresAt = now.AddDays(options.Value.SessionDays),
        });
    }

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static bool IsUniqueViolation(DbUpdateException e) =>
        e.InnerException is Npgsql.PostgresException { SqlState: Npgsql.PostgresErrorCodes.UniqueViolation };
}