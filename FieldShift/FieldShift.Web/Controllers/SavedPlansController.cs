using System.Security.Claims;
using FieldShift.Web.Accounts;
using FieldShift.Web.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

/// <summary>
/// The rotation plans the logged-in user chose to keep. Errors are ProblemDetails with a <c>code</c>
/// (<see cref="SavedPlanErrorCodes"/> or <see cref="AccountErrorCodes.DatabaseUnavailable"/>).
/// </summary>
[ApiController]
[Route("api/me/plans")]
[Authorize]
public class SavedPlansController(SavedPlanService plans) : ControllerBase
{
    private const int DefaultLimit = 20;
    private const int MaxLimit = 100;

    /// <summary>Keeps a plan in the user's profile.</summary>
    /// <response code="201">The saved plan.</response>
    /// <response code="400"><c>invalid_location</c>, <c>invalid_goal</c>, <c>invalid_plan</c>, <c>invalid_answers</c> or <c>too_many_plans</c>.</response>
    /// <response code="401">No valid token.</response>
    /// <response code="503"><c>database_unavailable</c>.</response>
    [HttpPost]
    [ProducesResponseType<SavedPlanResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<SavedPlanResponse>> Save([FromBody] SavePlanRequest request, CancellationToken ct)
    {
        if (SavedPlanRules.Validate(request) is { } invalid)
        {
            return Error(StatusCodes.Status400BadRequest, invalid, "The plan to save is not valid.");
        }

        try
        {
            var saved = await plans.SaveAsync(UserId, request, ct);
            return saved is null
                ? Error(StatusCodes.Status400BadRequest, SavedPlanErrorCodes.TooManyPlans,
                    $"At most {SavedPlanRules.MaxPlansPerUser} plans can be saved. Delete one first.")
                : StatusCode(StatusCodes.Status201Created, SavedPlanService.ToResponse(saved));
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return Unavailable();
        }
    }

    /// <summary>The user's saved plans, newest first.</summary>
    /// <param name="limit">How many (default 20, at most 100).</param>
    /// <param name="ct">Cancels the request.</param>
    /// <response code="200">The plans (possibly none).</response>
    /// <response code="503"><c>database_unavailable</c>.</response>
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<SavedPlanResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<IReadOnlyList<SavedPlanResponse>>> List(
        [FromQuery] int limit = DefaultLimit, CancellationToken ct = default)
    {
        try
        {
            var saved = await plans.ListAsync(UserId, Math.Clamp(limit, 1, MaxLimit), ct);
            return Ok(saved.Select(SavedPlanService.ToResponse).ToList());
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return Unavailable();
        }
    }

    /// <summary>Removes one of the user's saved plans.</summary>
    /// <response code="204">Removed.</response>
    /// <response code="404">No such plan for this user.</response>
    /// <response code="503"><c>database_unavailable</c>.</response>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        try
        {
            return await plans.DeleteAsync(UserId, id, ct) ? NoContent() : NotFound();
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return Unavailable();
        }
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private ObjectResult Unavailable() => Error(StatusCodes.Status503ServiceUnavailable,
        AccountErrorCodes.DatabaseUnavailable, "The database is unavailable. Try again later.");

    private ObjectResult Error(int status, string code, string detail)
    {
        var problem = ProblemDetailsFactory.CreateProblemDetails(HttpContext, status, detail: detail);
        problem.Extensions["code"] = code;
        return new ObjectResult(problem) { StatusCode = status };
    }
}
