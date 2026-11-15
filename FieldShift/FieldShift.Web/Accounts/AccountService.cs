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
}

/// <summary>Error codes sent to the frontend (it translates them; never display text).</summary>
public static class AccountErrorCodes
{
    public const string InvalidEmail = "invalid_email";
    public const string PasswordTooShort = "password_too_short";
    public const string PasswordTooLong = "password_too_long";
    public const string EmailTaken = "email_taken";
    public const string InvalidCredentials = "invalid_credentials";
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
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 128;
    private const int MaxEmailLength = 254;

    private static readonly PasswordHasher<User> Hasher = new();

    /// <summary>Hash checked when the email is unknown, so a wrong email takes as long as a wrong password.</summary>
    private static readonly string DummyHash = Hasher.HashPassword(null!, "not-a-real-password");

    public async Task<AccountResult> RegisterAsync(string? email, string? password, CancellationToken ct)
    {
        var normalized = NormalizeEmail(email);
        if (normalized is null)
        {
            return AccountResult.Fail(AccountErrorCodes.InvalidEmail);
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

        if (await db.Users.AnyAsync(u => u.Email == normalized, ct))
        {
            return AccountResult.Fail(AccountErrorCodes.EmailTaken);
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = normalized,
            PasswordHash = "",
            CreatedAt = time.GetUtcNow(),
        };
        user.PasswordHash = Hasher.HashPassword(user, password);
        db.Users.Add(user);

        var (token, session) = NewSession(user.Id);
        db.Sessions.Add(session);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (IsUniqueViolation(e))
        {
            // Two registrations with the same email at the same moment.
            return AccountResult.Fail(AccountErrorCodes.EmailTaken);
        }

        return new AccountResult(user, token, session.ExpiresAt, null);
    }

    public async Task<AccountResult> LoginAsync(string? email, string? password, CancellationToken ct)
    {
        var normalized = NormalizeEmail(email);
        if (normalized is null || string.IsNullOrEmpty(password) || password.Length > MaxPasswordLength)
        {
            return AccountResult.Fail(AccountErrorCodes.InvalidCredentials);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        var user = await db.Users.SingleOrDefaultAsync(u => u.Email == normalized, ct);
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

        // Drop this user's expired sessions while we are here.
        var now = time.GetUtcNow();
        await db.Sessions.Where(s => s.UserId == user.Id && s.ExpiresAt <= now).ExecuteDeleteAsync(ct);

        var (token, session) = NewSession(user.Id);
        db.Sessions.Add(session);
        await db.SaveChangesAsync(ct);

        return new AccountResult(user, token, session.ExpiresAt, null);
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

    /// <summary>Trimmed, lower-case email, or null when it does not look like one.</summary>
    internal static string? NormalizeEmail(string? email)
    {
        var e = email?.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(e) || e.Length > MaxEmailLength || e.Any(char.IsWhiteSpace))
        {
            return null;
        }

        var at = e.IndexOf('@');
        return at > 0 && at == e.LastIndexOf('@') && at < e.Length - 1 ? e : null;
    }

    internal static string HashToken(string token) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

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