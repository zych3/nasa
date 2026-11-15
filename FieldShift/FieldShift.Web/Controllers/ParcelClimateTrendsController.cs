using FieldShift.Web.ClimateTrends;
using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/parcels/climate-trends")]
public class ParcelClimateTrendsController(ClimateTrendsProvider provider) : ControllerBase
{
    private const int MaxParcelIdLength = 100;

    /// <summary>
    /// Clear long-term climate changes in the area of a parcel since 1981 (frost-free season, heat, dry spells,
    /// heavy rain), at most three, with long-term options as advice codes. Facts about past years, not a forecast.
    /// Give <paramref name="parcelId"/>, or <paramref name="lat"/> and <paramref name="lon"/> of a point on the
    /// parcel (or both: the point is the fallback when the parcel is not found).
    /// </summary>
    /// <param name="parcelId">Full parcel identifier, e.g. "141205_2.0008.60".</param>
    /// <param name="lat">Latitude in decimal degrees.</param>
    /// <param name="lon">Longitude in decimal degrees.</param>
    /// <param name="ct">Request cancellation.</param>
    /// <response code="200">
    /// See <c>status</c>: "ok", "no_clear_trends" (nothing clear enough to show) or "no_data".
    /// </response>
    /// <response code="400">Neither a parcel id nor valid coordinates.</response>
    /// <response code="404">No parcel with this id (and no coordinates to fall back on).</response>
    /// <response code="502">NASA POWER (or, with a parcel id alone, the parcel register) is unavailable.</response>
    [HttpGet]
    [ProducesResponseType<ClimateTrendsResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<ClimateTrendsResponse>> Get(
        [FromQuery] string? parcelId,
        [FromQuery] double? lat,
        [FromQuery] double? lon,
        CancellationToken ct)
    {
        var hasId = !string.IsNullOrWhiteSpace(parcelId);
        if (hasId && parcelId!.Length > MaxParcelIdLength)
        {
            return Problem($"Parcel id is too long (max {MaxParcelIdLength} characters).",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var hasPoint = lat is not null || lon is not null;
        if (hasPoint && (lat is not (>= -90 and <= 90) || lon is not (>= -180 and <= 180)))
        {
            return Problem("Both lat (-90..90) and lon (-180..180) are required when one is given.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (!hasId && !hasPoint)
        {
            return Problem("Give parcelId, or lat and lon.", statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            var trends = await provider.GetAsync(hasId ? parcelId : null, lat, lon, ct);
            return trends is null
                ? Problem("Parcel not found.", statusCode: StatusCodes.Status404NotFound)
                : trends;
        }
        catch (UpstreamServiceException ex)
        {
            return Problem($"{ex.Service} is unavailable. Try again later.", statusCode: StatusCodes.Status502BadGateway);
        }
    }
}
