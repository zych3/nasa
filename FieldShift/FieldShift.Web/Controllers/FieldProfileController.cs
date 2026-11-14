using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/field-profile")]
public class FieldProfileController(FieldProfileProvider provider) : ControllerBase
{
    /// <summary>Climate (NASA POWER) and topsoil (SoilGrids) profile of a field at the given point.</summary>
    /// <param name="lat">Latitude in decimal degrees, −90…90.</param>
    /// <param name="lon">Longitude in decimal degrees, −180…180.</param>
    /// <param name="ct">Request cancellation.</param>
    /// <response code="200">Profile. <c>soil</c> is null (with a warning) when soil data is unavailable.</response>
    /// <response code="400">Missing or out-of-range coordinates.</response>
    /// <response code="502">NASA POWER is unavailable, so no profile can be built.</response>
    [HttpGet]
    [ProducesResponseType<FieldProfileResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<FieldProfileResponse>> Get(
        [FromQuery] double? lat,
        [FromQuery] double? lon,
        CancellationToken ct)
    {
        if (lat is not { } latitude || !double.IsFinite(latitude) || latitude is < -90 or > 90)
        {
            return Problem("Query parameter 'lat' is required and must be between -90 and 90.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (lon is not { } longitude || !double.IsFinite(longitude) || longitude is < -180 or > 180)
        {
            return Problem("Query parameter 'lon' is required and must be between -180 and 180.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            return await provider.GetAsync(latitude, longitude, ct);
        }
        catch (UpstreamServiceException ex)
        {
            return Problem($"{ex.Service} is unavailable, cannot build the field profile. Try again later.",
                statusCode: StatusCodes.Status502BadGateway);
        }
    }
}
