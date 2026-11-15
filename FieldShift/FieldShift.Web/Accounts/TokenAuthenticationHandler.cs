using System.Globalization;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace FieldShift.Web.Accounts;

/// <summary>
/// Reads <c>Authorization: Bearer &lt;token&gt;</c> and looks the session up in the database. Endpoints marked
/// <c>[Authorize]</c> answer 401 without a valid token; all other endpoints work as before without one.
/// The user id is in the <see cref="ClaimTypes.NameIdentifier"/> claim.
/// </summary>
public sealed class TokenAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    AccountService accounts)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Bearer";

    /// <summary>Claim with the account's creation time (ISO 8601).</summary>
    public const string CreatedAtClaim = "fieldshift:created_at";

    /// <summary>The bearer token of the request, or null.</summary>
    public static string? ReadToken(HttpRequest request)
    {
        var header = request.Headers.Authorization.ToString();
        const string prefix = "Bearer ";
        return header.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) && header.Length > prefix.Length
            ? header[prefix.Length..].Trim()
            : null;
    }

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var token = ReadToken(Request);
        if (token is null)
        {
            return AuthenticateResult.NoResult();
        }

        User? user;
        try
        {
            user = await accounts.FindByTokenAsync(token, Context.RequestAborted);
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return AuthenticateResult.Fail("Accounts database unavailable.");
        }

        if (user is null)
        {
            return AuthenticateResult.Fail("Unknown or expired token.");
        }

        var identity = new ClaimsIdentity(
            [
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Username),
                new Claim(CreatedAtClaim, user.CreatedAt.ToString("O", CultureInfo.InvariantCulture)),
            ],
            SchemeName);
        return AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName));
    }
}