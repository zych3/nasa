using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;
using FieldShift.Web.MapLayers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/map-layers")]
public class MapLayersController(MapLayersService service, MapLayersGridService gridService, TimeProvider time)
    : ControllerBase
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
            return ValidationProblem(title: "Nieprawidłowe parametry zapytania.", modelStateDictionary: ToModelState(validation));
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

    /// <summary>
    /// The same monthly layers for a 5 × 5 block of NASA POWER cells (0.5° × 0.625°, about 250 km) around a point,
    /// to draw the area as a heat map. Only layers from NASA POWER alone (no soil, no soil erosion).
    /// </summary>
    /// <param name="lat">Latitude in decimal degrees, −90…90.</param>
    /// <param name="lon">Longitude in decimal degrees, −180…180.</param>
    /// <param name="from">First month "yyyy-MM" (default as in <c>/api/map-layers</c>).</param>
    /// <param name="to">Last month "yyyy-MM" (default as in <c>/api/map-layers</c>).</param>
    /// <param name="layers">Comma-separated layer ids (default: every layer the grid has).</param>
    /// <param name="ct">Request cancellation.</param>
    /// <response code="200">Cells and layers; every series has the same length as <c>dates</c>.</response>
    /// <response code="400">Invalid parameters or a layer the grid does not have (messages in Polish).</response>
    /// <response code="502">NASA POWER did not answer for any cell.</response>
    [HttpGet("grid")]
    [ProducesResponseType<MapLayersGridResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<MapLayersGridResponse>> GetGrid(
        [FromQuery] double? lat,
        [FromQuery] double? lon,
        [FromQuery] string? from,
        [FromQuery] string? to,
        [FromQuery] string? layers,
        CancellationToken ct)
    {
        var today = DateOnly.FromDateTime(time.GetUtcNow().UtcDateTime);
        var validation = MapLayersRequestValidator.Validate(lat, lon, from, to, layers, today);
        var request = validation.Request;
        var layersError = request is not null && !string.IsNullOrWhiteSpace(layers)
            ? MapLayersGridService.UnsupportedLayersError(request.LayerIds)
            : null;
        if (!validation.IsValid || layersError is not null)
        {
            var modelState = ToModelState(validation);
            if (layersError is not null)
            {
                modelState.AddModelError("layers", layersError);
            }

            return ValidationProblem(title: "Nieprawidłowe parametry zapytania.", modelStateDictionary: modelState);
        }

        try
        {
            var response = await gridService.GetAsync(
                request! with { LayerIds = MapLayersGridService.DefaultLayerIds(request.LayerIds) }, ct);
            Response.Headers.CacheControl = CacheControl;
            return response;
        }
        catch (UpstreamServiceException)
        {
            return Problem("NASA POWER jest chwilowo niedostępne – spróbuj ponownie później.",
                statusCode: StatusCodes.Status502BadGateway);
        }
    }

    private static ModelStateDictionary ToModelState(MapLayersValidation validation)
    {
        var modelState = new ModelStateDictionary();
        foreach (var (key, messages) in validation.Errors)
        {
            foreach (var message in messages)
            {
                modelState.AddModelError(key, message);
            }
        }

        return modelState;
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
