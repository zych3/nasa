using FieldShift.Web.FieldData;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

/// <summary>
/// Web map tiles of data layers (today: the Polish soil map), for the app's map, through our cache, so the app
/// never asks the sources itself.
/// </summary>
[ApiController]
[Route("api/map-tiles")]
public class MapTilesController(MapTileService tiles) : ControllerBase
{
    /// <summary>One 256 px PNG tile (z/x/y as OpenStreetMap). Transparent where the layer has nothing.</summary>
    /// <response code="200">The tile.</response>
    /// <response code="404">Unknown layer or impossible tile.</response>
    [HttpGet("{layer}/{z:int}/{x:int}/{y:int}.png")]
    public async Task<IActionResult> Tile(string layer, int z, int x, int y, CancellationToken ct)
    {
        var tile = new TileAddress(z, x, y);
        if (!tiles.HasLayer(layer) || !tile.IsValid)
        {
            return NotFound();
        }

        var png = await tiles.GetAsync(layer, tile, ct);
        // An empty tile may only mean the source failed: let the browser ask again soon.
        Response.Headers.CacheControl = ReferenceEquals(png, MapTileService.Empty)
            ? "public, max-age=300"
            : "public, max-age=86400";
        return File(png, "image/png");
    }

    /// <summary>What the layer's colours mean: code, name (Polish) and colour "#RRGGBB".</summary>
    /// <response code="200">The legend.</response>
    /// <response code="404">Unknown layer.</response>
    [HttpGet("{layer}/legend")]
    [ProducesResponseType<IReadOnlyList<MapLegendItem>>(StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<MapLegendItem>> Legend(string layer)
    {
        if (tiles.Legend(layer) is not { } legend)
        {
            return NotFound();
        }

        Response.Headers.CacheControl = "public, max-age=86400";
        return Ok(legend);
    }
}
