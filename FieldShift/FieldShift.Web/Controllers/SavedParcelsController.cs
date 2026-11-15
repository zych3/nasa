using System.Security.Claims;
using FieldShift.Web.Accounts;
using FieldShift.Web.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

/// <summary>
/// The logged-in user's "My parcels", kept in step with the copy on their devices. The device is the main copy;
/// this is a backup that other devices can load. Errors are ProblemDetails with a <c>code</c>
/// (<see cref="SavedParcelErrorCodes"/> or <see cref="AccountErrorCodes.DatabaseUnavailable"/>).
/// </summary>
[ApiController]
[Route("api/me/parcels")]
[Authorize]
public class SavedParcelsController(SavedParcelService parcels) : ControllerBase
{
    /// <summary>Sends the device's list and gets the merged list back (the newer change of each parcel wins).</summary>
    /// <response code="200">The merged list, with removals the device has to apply.</response>
    /// <response code="400"><c>invalid_parcels</c> or <c>too_many_parcels</c>.</response>
    /// <response code="401">No valid token.</response>
    /// <response code="503"><c>database_unavailable</c>.</response>
    [HttpPost("sync")]
    [ProducesResponseType<SyncParcelsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<ActionResult<SyncParcelsResponse>> Sync([FromBody] SyncParcelsRequest request, CancellationToken ct)
    {
        if (SavedParcelRules.Validate(request) is { } invalid)
        {
            return Error(StatusCodes.Status400BadRequest, invalid, "The parcels to sync are not valid.");
        }

        try
        {
            var merged = await parcels.SyncAsync(UserId, request, ct);
            return merged is null
                ? Error(StatusCodes.Status400BadRequest, SavedParcelErrorCodes.TooManyParcels,
                    $"At most {SavedParcelRules.MaxParcelsPerUser} parcels can be saved. Remove one first.")
                : Ok(merged);
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return Error(StatusCodes.Status503ServiceUnavailable, AccountErrorCodes.DatabaseUnavailable,
                "The database is unavailable. Try again later.");
        }
    }

    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private ObjectResult Error(int status, string code, string detail)
    {
        var problem = ProblemDetailsFactory.CreateProblemDetails(HttpContext, status, detail: detail);
        problem.Extensions["code"] = code;
        return new ObjectResult(problem) { StatusCode = status };
    }
}
