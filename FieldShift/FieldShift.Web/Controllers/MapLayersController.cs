using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using FieldShift.Web.MapLayers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/map-layers")]
public class MapLayersController(MapLayersService service, TimeProvider time) : ControllerBase
{
    private const string CacheControl = "public, max-age=3600";

    /// <summary>Monthly time series of climate and soil map layers for a point, with legends and descriptions.</summary>
    /// <param name="lat">Latitude in decimal degrees, −90…90.</param>
    /// <param name="lon">Longitude in decimal degrees, −180…180.</param>
    /// <param name="from">First month "yyyy-MM" (default: January 10 full years ago).</param>
    /// <param name="to">Last month "yyyy-MM", at most the last full month (default: December of last year). Max range 15 years.</param>
    /// <param name="layers">Comma-separated layer ids (default: all), see <c>/api/map-layers/definitions</c>.</param>
    /// <param name="ct">Request cancellation.</param>
    /// <response code="200">Layers; every <c>values</c> array has the same length as <c>dates</c>.</response>
    /// <response code="400">Invalid parameters (messages in Polish).</response>
    /// <response code="502">NASA POWER is unavailable.</response>
    [HttpGet]
    [ProducesResponseType<MapLayersResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<MapLayersResponse>> Get(
        [FromQuery] double? lat,
        [FromQuery] double? lon,
        [FromQuery] string? from,
        [FromQuery] string? to,
        [FromQuery] string? layers,
        CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(time.GetUtcNow().UtcDateTime);
        var validation = MapLayersRequestValidator.Validate(lat, lon, from, to, layers, today);
        if (!validation.IsValid)
        {
            var modelState = new ModelStateDictionary();
            foreach (var (key, messages) in validation.Errors)
            {
                foreach (var message in messages)
                {
                    modelState.AddModelError(key, message);
                }
            }

            return ValidationProblem(title: "Nieprawidłowe parametry zapytania.", modelStateDictionary: modelState);
        }

        try
        {
            var response = await service.GetAsync(validation.Request!, ct);
            Response.Headers.CacheControl = CacheControl;
            return response;
        }
        catch (UpstreamServiceException)
        {
            return Problem("NASA POWER jest chwilowo niedostępne – spróbuj ponownie później.",
                statusCode: StatusCodes.Status502BadGateway);
        }
    }

    /// <summary>Layer definitions only (no data): ids, names, units, groups, legends. Use it to build the layer switcher.</summary>
    [HttpGet("definitions")]
    [ProducesResponseType<IReadOnlyList<LayerDefinitionDto>>(StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<LayerDefinitionDto>> GetDefinitions()
    {
        Response.Headers.CacheControl = CacheControl;
        return LayerDefinitions.All.Select(d => d.ToDto()).ToList();
    }
}
