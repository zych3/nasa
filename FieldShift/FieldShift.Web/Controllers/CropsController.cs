using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/crops")]
public class CropsController(ICropRepository crops, CropPriceService prices) : ControllerBase
{
    /// <summary>Crop catalogue: names, Wikipedia photo and links, Polish area and yield, growing traits.</summary>
    [HttpGet]
    public ActionResult<IReadOnlyList<Crop>> GetAll() => Ok(crops.GetAll());

    [HttpGet("{id}")]
    public ActionResult<Crop> GetById(string id) =>
        crops.GetById(new CropId(id)) is { } crop ? Ok(crop) : NotFound();

    /// <summary>
    /// The latest <paramref name="count"/> real prices per tonne, oldest first.
    /// Crops without published prices return <c>status: "no_data"</c> and an empty list.
    /// </summary>
    [HttpGet("{id}/prices")]
    public ActionResult<PriceHistory> GetPrices(string id, [FromQuery] int count = CropPriceService.DefaultCount)
    {
        if (count is < 1 or > CropPriceService.MaxCount)
        {
            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                detail: $"'count' must be between 1 and {CropPriceService.MaxCount}.");
        }

        var history = prices.GetLatest(new CropId(id), count);
        return history is null ? NotFound() : Ok(history);
    }
}
