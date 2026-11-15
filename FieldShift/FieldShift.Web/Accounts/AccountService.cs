using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

/// <summary>Codes sent to the app when signing in or up fails (the app shows its own words for them).</summary>
public static class AccountErrorCodes
{
    public const string InvalidEmail = "invalid_email";
    public const string PasswordTooShort = "password_too_short";
    public const string EmailTaken = "email_taken";
    public const string InvalidCredentials = "invalid_credentials";
    public const string DatabaseUnavailable = "database_unavailable";
}

/// <summary>The user as the app sees it.</summary>
public sealed record AccountUser(Guid Id, string Email, string? Name);

/// <summary>A successful sign-in: the token to send as <c>Authorization: Bearer ...</c>.</summary>
public sealed record AccountSession(string Token, DateTimeOffset ExpiresAt, AccountUser User);

/// <summary>Result of sign-up / sign-in: either a session or an error code from <see cref="AccountErrorCodes"/>.</summary>
public sealed record AccountResult(AccountSession? Session, string? ErrorCode)
{
    public static AccountResult Ok(AccountSession session) => new(session, null);

    public static AccountResult Error(string code) => new(null, code);
}

public sealed class AccountService(
    IDbContextFactory<AccountsDbContext> factory,
    AccountsSchema schema,
    TimeProvider clock)
{
    public const int MinPasswordLength = 8;
    public const int MaxPasswordLength = 200;
    public static readonly TimeSpan SessionLifetime = TimeSpan.FromDays(30);

    private static readonly PasswordHasher<UserAccount> Hasher = new();

    /// <summary>Lower-cased, trimmed e-mail, or null when it is not an e-mail address.</summary>
    public static string? NormalizeEmail(string? email)
    {
        var text = email?.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(text) || text.Length > 254 || !text.Contains('@'))
        {
            return null;
        }

        return MailAddress.TryCreate(text, out var address) && address.Address == text && address.Host.Contains('.')
            ? text
            : null;
    }

    /// <summary>The value stored for a token (SHA-256, hex).</summary>
    public static string HashToken(string token) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

    public async Task<AccountResult> RegisterAsync(string? email, string? password, string? name, CancellationToken ct)
    {
        var normalized = NormalizeEmail(email);
        if (normalized is null)
        {
            return AccountResult.Error(AccountErrorCodes.InvalidEmail);
        }

        if (password is null || password.Length < MinPasswordLength || password.Length > MaxPasswordLength)
        {
            return AccountResult.Error(AccountErrorCodes.PasswordTooShort);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await factory.CreateDbContextAsync(ct);
        if (await db.Users.AnyAsync(u => u.Email == normalized, ct))
        {
            return AccountResult.Error(AccountErrorCodes.EmailTaken);
        }

        var cleanName = name?.Trim();
        var user = new UserAccount
        {
            Id = Guid.NewGuid(),
            Email = normalized,
            Name = string.IsNullOrEmpty(cleanName) ? null : cleanName[..Math.Min(cleanName.Length, 100)],
            PasswordHash = "",
            CreatedAt = clock.GetUtcNow(),
        };
        user.PasswordHash = Hasher.HashPassword(user, password);
        db.Users.Add(user);

        try
        {
            var session = AddSession(db, user);
            await db.SaveChangesAsync(ct);
            return AccountResult.Ok(session);
        }
        catch (DbUpdateException)
        {
            // Two sign-ups with the same e-mail at once: the unique index stopped the second one.
            if (await EmailExistsAsync(normalized, ct))
            {
                return AccountResult.Error(AccountErrorCodes.EmailTaken);
            }

            throw;
        }
    }

    public async Task<AccountResult> LoginAsync(string? email, string? password, CancellationToken ct)
    {
        var normalized = NormalizeEmail(email);
        if (normalized is null || string.IsNullOrEmpty(password) || password.Length > MaxPasswordLength)
        {
            return AccountResult.Error(AccountErrorCodes.InvalidCredentials);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await factory.CreateDbContextAsync(ct);
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == normalized, ct);
        if (user is null)
        {
            return AccountResult.Error(AccountErrorCodes.InvalidCredentials);
        }

        var check = Hasher.VerifyHashedPassword(user, user.PasswordHash, password);
        if (check == PasswordVerificationResult.Failed)
        {
            return AccountResult.Error(AccountErrorCodes.InvalidCredentials);
        }

        if (check == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = Hasher.HashPassword(user, password);
        }

        var session = AddSession(db, user);
        await db.SaveChangesAsync(ct);
        return AccountResult.Ok(session);
    }

    /// <summary>The user of a valid, unexpired token; null otherwise.</summary>
    public async Task<AccountUser?> GetUserAsync(string token, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await factory.CreateDbContextAsync(ct);
        var hash = HashToken(token);
        var now = clock.GetUtcNow();
        var user = await (
                from s in db.Sessions
                join u in db.Users on s.UserId equals u.Id
                where s.TokenHash == hash && s.ExpiresAt > now
                select u)
            .FirstOrDefaultAsync(ct);
        return user is null ? null : ToUser(user);
    }

    /// <summary>Ends the session of <paramref name="token"/> (no-op when unknown).</summary>
    public async Task LogoutAsync(string token, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await factory.CreateDbContextAsync(ct);
        var hash = HashToken(token);
        await db.Sessions.Where(s => s.TokenHash == hash).ExecuteDeleteAsync(ct);
    }

    private AccountSession AddSession(AccountsDbContext db, UserAccount user)
    {
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .Replace('+', '-').Replace('/', '_').TrimEnd('=');
        var now = clock.GetUtcNow();
        var expires = now + SessionLifetime;
        db.Sessions.Add(new UserSession
        {
            TokenHash = HashToken(token),
            UserId = user.Id,
            CreatedAt = now,
            ExpiresAt = expires,
        });
        return new AccountSession(token, expires, ToUser(user));
    }

    private async Task<bool> EmailExistsAsync(string email, CancellationToken ct)
    {
        await using var db = await factory.CreateDbContextAsync(ct);
        return await db.Users.AnyAsync(u => u.Email == email, ct);
    }

    private static AccountUser ToUser(UserAccount user) => new(user.Id, user.Email, user.Name);
}
