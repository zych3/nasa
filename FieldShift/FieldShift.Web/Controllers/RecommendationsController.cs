using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using FieldShift.Web.Recommendations;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/recommendations")]
public class RecommendationsController(RecommendationProvider provider) : ControllerBase
{
    private const int MaxPastCrops = 10;

    /// <summary>
    /// Ranked crop-rotation plans for one plot. NASA POWER climate and SoilGrids soil are fetched for the location;
    /// the farmer's answers (past crops required, everything else optional) are added.
    /// </summary>
    /// <response code="200">Plans per goal. <c>status</c> is "no_plan" when no crop suits the plot.</response>
    /// <response code="400">Missing or invalid input.</response>
    /// <response code="502">NASA POWER is unavailable.</response>
    [HttpPost]
    [ProducesResponseType<RecommendationResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<RecommendationResponse>> Post([FromBody] RecommendationRequest request, CancellationToken ct)
    {
        if (request.Lat is not { } lat || !double.IsFinite(lat) || lat is < -90 or > 90)
        {
            return Bad("'lat' is required and must be between -90 and 90.");
        }

        if (request.Lon is not { } lon || !double.IsFinite(lon) || lon is < -180 or > 180)
        {
            return Bad("'lon' is required and must be between -180 and 180.");
        }

        if (request.PastCrops is not { Count: > 0 and <= MaxPastCrops })
        {
            return Bad($"'pastCrops' is required: 1 to {MaxPastCrops} crop ids, most recent first.");
        }

        var goal = request.Goal ?? RecommendationProvider.Balanced;
        if (!RecommendationProvider.IsGoal(goal))
        {
            return Bad("'goal' must be \"balanced\", \"soil_health\" or \"safe_harvest\".");
        }

        if (request.SoilPhKCl is { } ph && (!double.IsFinite(ph) || ph is < 3 or > 9))
        {
            return Bad("'soilPhKCl' must be between 3 and 9.");
        }

        try
        {
            return await provider.RecommendAsync(request, lat, lon, goal, ct);
        }
        catch (UpstreamServiceException ex)
        {
            return Problem($"{ex.Service} is unavailable, cannot build recommendations. Try again later.",
                statusCode: StatusCodes.Status502BadGateway);
        }
    }

    private ObjectResult Bad(string detail) => Problem(detail, statusCode: StatusCodes.Status400BadRequest);
}
