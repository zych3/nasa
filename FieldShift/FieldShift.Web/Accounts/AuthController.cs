using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Accounts;

public sealed record RegisterRequest(string? Email, string? Password, string? Name);

public sealed record LoginRequest(string? Email, string? Password);

/// <summary>Error body: a code from <see cref="AccountErrorCodes"/>, never a sentence.</summary>
public sealed record AccountError(string Code);

/// <summary>
/// Sign-up and sign-in. A successful call returns a token; the app sends it back as
/// <c>Authorization: Bearer &lt;token&gt;</c>.
/// </summary>
[ApiController]
[Route("api/auth")]
public sealed class AuthController(AccountService accounts, ILogger<AuthController> logger) : ControllerBase
{
    /// <summary>Creates an account and signs in. 400 invalid_email / password_too_short, 409 email_taken.</summary>
    [HttpPost("register")]
    public Task<ActionResult<AccountSession>> Register([FromBody] RegisterRequest body, CancellationToken ct) =>
        Run(() => accounts.RegisterAsync(body.Email, body.Password, body.Name, ct));

    /// <summary>Signs in. 401 invalid_credentials.</summary>
    [HttpPost("login")]
    public Task<ActionResult<AccountSession>> Login([FromBody] LoginRequest body, CancellationToken ct) =>
        Run(() => accounts.LoginAsync(body.Email, body.Password, ct));

    /// <summary>The signed-in user. 401 when the token is missing, wrong or expired.</summary>
    [HttpGet("me")]
    public async Task<ActionResult<AccountUser>> Me(CancellationToken ct)
    {
        if (BearerToken() is not { } token)
        {
            return Unauthorized(new AccountError(AccountErrorCodes.InvalidCredentials));
        }

        try
        {
            return await accounts.GetUserAsync(token, ct) is { } user
                ? user
                : Unauthorized(new AccountError(AccountErrorCodes.InvalidCredentials));
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return DatabaseDown(e);
        }
    }

    /// <summary>Ends this device's session.</summary>
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        if (BearerToken() is { } token)
        {
            try
            {
                await accounts.LogoutAsync(token, ct);
            }
            catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
            {
                return DatabaseDown(e);
            }
        }

        return NoContent();
    }

    private async Task<ActionResult<AccountSession>> Run(Func<Task<AccountResult>> action)
    {
        try
        {
            var result = await action();
            if (result.Session is { } session)
            {
                return session;
            }

            var error = new AccountError(result.ErrorCode!);
            return result.ErrorCode switch
            {
                AccountErrorCodes.EmailTaken => Conflict(error),
                AccountErrorCodes.InvalidCredentials => Unauthorized(error),
                _ => BadRequest(error),
            };
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return DatabaseDown(e);
        }
    }

    private ObjectResult DatabaseDown(Exception e)
    {
        logger.LogWarning(e, "Accounts database unavailable");
        return StatusCode(StatusCodes.Status503ServiceUnavailable,
            new AccountError(AccountErrorCodes.DatabaseUnavailable));
    }

    private string? BearerToken()
    {
        var header = Request.Headers.Authorization.ToString();
        const string prefix = "Bearer ";
        return header.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) && header.Length > prefix.Length
            ? header[prefix.Length..].Trim()
            : null;
    }
}
