using System.Security.Claims;
using FieldShift.Web.Accounts;
using FieldShift.Web.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

/// <summary>
/// The logged-in user's crops at their places ("my crops"), saved for a later risk check. Needs
/// <c>Authorization: Bearer &lt;token&gt;</c> (401 without it); every user sees only their own entries.
/// Errors are ProblemDetails with a <c>code</c> (see <see cref="UserCropErrorCodes"/>).
/// </summary>
[ApiController]
[Authorize]
[Route("api/my-crops")]
public class MyCropsController(UserCropService crops) : ControllerBase
{
    /// <summary>All entries of the user, newest first.</summary>
    /// <response code="200">The entries (empty list when none).</response>
    /// <response code="401">Not logged in.</response>
    [HttpGet]
    [ProducesResponseType<IReadOnlyList<UserCropResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public Task<ActionResult<IReadOnlyList<UserCropResponse>>> List(CancellationToken ct) =>
        WithDatabase<IReadOnlyList<UserCropResponse>>(async () =>
            (await crops.ListAsync(UserId, ct)).Select(UserCropService.ToResponse).ToList());

    /// <summary>One entry.</summary>
    /// <response code="404"><c>not_found</c> (also for another user's entry).</response>
    [HttpGet("{id:guid}")]
    [ProducesResponseType<UserCropResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<ActionResult<UserCropResponse>> Get(Guid id, CancellationToken ct) =>
        WithDatabase<UserCropResponse>(async () => await crops.GetAsync(UserId, id, ct) is { } crop
            ? UserCropService.ToResponse(crop)
            : Error(StatusCodes.Status404NotFound, UserCropErrorCodes.NotFound, "No such entry."));

    /// <summary>Adds an entry.</summary>
    /// <response code="201">The new entry.</response>
    /// <response code="400"><c>invalid_crop</c>, <c>invalid_location</c>, <c>label_too_long</c> or <c>too_many_crops</c>.</response>
    [HttpPost]
    [ProducesResponseType<UserCropResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<ActionResult<UserCropResponse>> Create([FromBody] UserCropCreateRequest request, CancellationToken ct) =>
        WithDatabase<UserCropResponse>(async () =>
        {
            var result = await crops.CreateAsync(UserId, request, ct);
            return result.Crop is { } crop
                ? CreatedAtAction(nameof(Get), new { id = crop.Id }, UserCropService.ToResponse(crop))
                : Fail(result.ErrorCode!);
        });

    /// <summary>
    /// Changes an entry: only the fields that are sent (crop, place as <c>latitude</c> + <c>longitude</c>,
    /// <c>parcelId</c>, label, active).
    /// </summary>
    /// <response code="200">The changed entry.</response>
    /// <response code="400"><c>invalid_crop</c>, <c>invalid_location</c> or <c>label_too_long</c>.</response>
    /// <response code="404"><c>not_found</c>.</response>
    [HttpPatch("{id:guid}")]
    [ProducesResponseType<UserCropResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<ActionResult<UserCropResponse>> Update(
        Guid id, [FromBody] UserCropUpdateRequest request, CancellationToken ct) =>
        WithDatabase<UserCropResponse>(async () =>
        {
            var result = await crops.UpdateAsync(UserId, id, request, ct);
            return result.Crop is { } crop ? UserCropService.ToResponse(crop) : Fail(result.ErrorCode!);
        });

    /// <summary>Set by <see cref="TokenAuthenticationHandler"/> for every request that passes [Authorize].</summary>
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private async Task<ActionResult<T>> WithDatabase<T>(Func<Task<ActionResult<T>>> action)
    {
        try
        {
            return await action();
        }
        catch (Exception e) when (AccountsDbContext.IsDatabaseFailure(e))
        {
            return Error(StatusCodes.Status503ServiceUnavailable, AccountErrorCodes.DatabaseUnavailable,
                "The accounts database is unavailable. Try again later.");
        }
    }

    private ObjectResult Fail(string code) => code switch
    {
        UserCropErrorCodes.NotFound => Error(StatusCodes.Status404NotFound, code, "No such entry."),
        UserCropErrorCodes.InvalidCrop => Error(StatusCodes.Status400BadRequest, code,
            "'cropId' must be a crop id from GET /api/crops."),
        UserCropErrorCodes.InvalidLocation => Error(StatusCodes.Status400BadRequest, code,
            "'latitude' (-90..90) and 'longitude' (-180..180) are required."),
        UserCropErrorCodes.LabelTooLong => Error(StatusCodes.Status400BadRequest, code,
            $"'label' can have at most {UserCropService.MaxLabelLength} characters."),
        _ => Error(StatusCodes.Status400BadRequest, code,
            $"At most {UserCropService.MaxCropsPerUser} entries per user."),
    };

    private ObjectResult Error(int status, string code, string detail)
    {
        var problem = ProblemDetailsFactory.CreateProblemDetails(HttpContext, status, detail: detail);
        problem.Extensions["code"] = code;
        return new ObjectResult(problem) { StatusCode = status };
    }
}
