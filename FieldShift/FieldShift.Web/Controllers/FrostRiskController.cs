using FieldShift.Web.DTOs;
using FieldShift.Web.Weather;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/weather")]
public class FrostRiskController(FrostRiskService service, ILogger<FrostRiskController> logger) : ControllerBase
{
    /// <summary>Frost risk in the coming 7 days at a point, from the weather forecast.</summary>
    [HttpGet("frost-risk")]
    public async Task<ActionResult<FrostRiskResponse>> Get(
        [FromQuery] double? lat, [FromQuery] double? lon, CancellationToken ct)
    {
        if (lat is not (>= -90 and <= 90) || lon is not (>= -180 and <= 180))
        {
            return Problem("Valid lat and lon are required.", statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            return await service.GetAsync(lat.Value, lon.Value, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or System.Text.Json.JsonException)
        {
            logger.LogWarning(ex, "Frost forecast failed");
            return Problem("Upstream service error.", statusCode: StatusCodes.Status502BadGateway);
        }
    }
}
