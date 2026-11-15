using System.Globalization;
using System.Security.Claims;
using FieldShift.Web.Accounts;
using FieldShift.Web.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

/// <summary>
/// Registration and login with a username and password. Errors are ProblemDetails with a <c>code</c>
/// (see <see cref="AccountErrorCodes"/>) that the frontend translates.
/// </summary>
[ApiController]
[Route("api/auth")]
public class AuthController(AccountService accounts) : ControllerBase
{
    /// <summary>Creates an account and logs it in.</summary>
    /// <response code="200">The new session.</response>
    /// <response code="400"><c>invalid_username</c>, <c>password_too_short</c> or <c>password_too_long</c>.</response>
    /// <response code="409"><c>username_taken</c>.</response>
    /// <response code="503"><c>database_unavailable</c>.</response>
    [HttpPost("register")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public Task<ActionResult<AuthResponse>> Register([FromBody] AuthRequest request, CancellationToken ct) =>
        Run(() => accounts.RegisterAsync(request.Username, request.Password, ct));

    /// <summary>Logs in with username and password.</summary>
    /// <response code="200">A new session.</response>
    /// <response code="401"><c>invalid_credentials</c> (wrong username or password; the answer does not say which).</response>
    /// <response code="503"><c>database_unavailable</c>.</response>
    [HttpPost("login")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public Task<ActionResult<AuthResponse>> Login([FromBody] AuthRequest request, CancellationToken ct) =>
        Run(() => accounts.LoginAsync(request.Username, request.Password, ct));

    /// <summary>
    /// Testing only: logs into the shared "test" account without a password. Works only when
    /// <c>Accounts:TestLogin</c> is true (Development, docker compose); otherwise 404.
    /// </summary>
    /// <response code="200">A session for the "test" account.</response>
    /// <response code="404">Test login is switched off.</response>
    [HttpPost("test-login")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AuthResponse>> TestLogin(CancellationToken ct) =>
        accounts.TestLoginEnabled ? await Run(() => accounts.TestLoginAsync(ct)) : NotFound();

    /// <summary>Ends the session of the bearer token.</summary>
    /// <response code="204">Logged out.</response>
    [HttpPost("logout")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        if (TokenAuthenticationHandler.ReadToken(Request) is { } token)
        {
            await accounts.LogoutAsync(token, ct);
        }

        return NoContent();
    }

    /// <summary>The logged-in user.</summary>
    /// <response code="200">The user of the bearer token.</response>
    /// <response code="401">No token, or it is unknown or expired.</response>
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType<UserResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public ActionResult<UserResponse> Me() => new UserResponse
    {
        Id = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!),
        Username = User.FindFirstValue(ClaimTypes.Name)!,
        CreatedAt = DateTimeOffset.Parse(
            User.FindFirstValue(TokenAuthenticationHandler.CreatedAtClaim)!, CultureInfo.InvariantCulture),
    };

    private async Task<ActionResult<AuthResponse>> Run(Func<Task<AccountResult>> action)
    {
        AccountResult result;
        try
        {
            result = await action();
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return Error(StatusCodes.Status503ServiceUnavailable, AccountErrorCodes.DatabaseUnavailable,
                "The accounts database is unavailable. Try again later.");
        }

        return result switch
        {
            { User: { } user, Token: { } token, ExpiresAt: { } expiresAt } =>
                new AuthResponse { Token = token, ExpiresAt = expiresAt, User = ToResponse(user) },
            { ErrorCode: AccountErrorCodes.UsernameTaken } =>
                Error(StatusCodes.Status409Conflict, AccountErrorCodes.UsernameTaken, "This username is already taken."),
            { ErrorCode: AccountErrorCodes.InvalidCredentials } =>
                Error(StatusCodes.Status401Unauthorized, AccountErrorCodes.InvalidCredentials, "Wrong username or password."),
            { ErrorCode: AccountErrorCodes.InvalidUsername } =>
                Error(StatusCodes.Status400BadRequest, AccountErrorCodes.InvalidUsername,
                    $"'username' must have {AccountService.MinUsernameLength}–{AccountService.MaxUsernameLength} letters, digits, '.', '_' or '-'."),
            { ErrorCode: AccountErrorCodes.PasswordTooShort } =>
                Error(StatusCodes.Status400BadRequest, AccountErrorCodes.PasswordTooShort,
                    $"'password' must have at least {AccountService.MinPasswordLength} characters."),
            _ =>
                Error(StatusCodes.Status400BadRequest, AccountErrorCodes.PasswordTooLong,
                    $"'password' must have at most {AccountService.MaxPasswordLength} characters."),
        };
    }

    private static UserResponse ToResponse(User user) =>
        new() { Id = user.Id, Username = user.Username, CreatedAt = user.CreatedAt };

    private ObjectResult Error(int status, string code, string detail)
    {
        var problem = ProblemDetailsFactory.CreateProblemDetails(HttpContext, status, detail: detail);
        problem.Extensions["code"] = code;
        return new ObjectResult(problem) { StatusCode = status };
    }
}