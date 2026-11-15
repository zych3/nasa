using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Satellite;

[ApiController]
[Route("api/satellite")]
public sealed class SatelliteController(SatelliteService satellite) : ControllerBase
{
    /// <summary>
    /// What NASA MODIS satellites saw at a field: plant greenness (NDVI, 250 m), land surface temperature (1 km)
    /// and evapotranspiration (500 m), each against the same time of year in the previous years. Each section has
    /// its own status ("ok", "noData", "unavailable"), so the answer is 200 even when a source is down.
    /// </summary>
    /// <param name="lat">Latitude in decimal degrees, −90…90.</param>
    /// <param name="lon">Longitude in decimal degrees, −180…180.</param>
    /// <param name="ct">Request cancellation.</param>
    [HttpGet]
    [ProducesResponseType<SatelliteResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<SatelliteResponse>> Get(
        [FromQuery] double? lat, [FromQuery] double? lon, CancellationToken ct)
    {
        if (lat is not (>= -90 and <= 90) || lon is not (>= -180 and <= 180))
        {
            return Problem("Valid lat and lon are required.", statusCode: StatusCodes.Status400BadRequest);
        }

        Response.Headers.CacheControl = "public, max-age=3600";
        return await satellite.GetAsync(lat.Value, lon.Value, ct);
    }

    /// <summary>
    /// One part of <see cref="Get"/>: rain, soil, vegetation, surface-temperature or evapotranspiration. The app asks
    /// for them one by one, so each shows as soon as it is ready.
    /// </summary>
    [HttpGet("{part}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<object>> GetPart(
        string part, [FromQuery] double? lat, [FromQuery] double? lon, CancellationToken ct)
    {
        if (!SatelliteService.Parts.Contains(part))
        {
            return Problem($"Unknown part '{part}'. Parts: {string.Join(", ", SatelliteService.Parts)}.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (lat is not (>= -90 and <= 90) || lon is not (>= -180 and <= 180))
        {
            return Problem("Valid lat and lon are required.", statusCode: StatusCodes.Status400BadRequest);
        }

        Response.Headers.CacheControl = "public, max-age=3600";
        return Ok(await satellite.GetPartAsync(part, lat.Value, lon.Value, ct));
    }
}
