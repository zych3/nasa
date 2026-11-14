using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/crops")]
public class CropsController(ICropRepository crops, CropPriceService prices) : ControllerBase
{
    /// <summary>Daily price per tonne for the last <paramref name="days"/> days, oldest first.</summary>
    [HttpGet("{id}/prices")]
    public ActionResult<IReadOnlyList<CropPrice>> GetPrices(string id, [FromQuery] int days = 30)
    {
        if (days is < 1 or > CropPriceService.MaxDays)
        {
            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                detail: $"'days' must be between 1 and {CropPriceService.MaxDays}.");
        }

        var cropId = new CropId(id);
        if (crops.GetById(cropId) is null)
        {
            return NotFound();
        }

        var history = prices.GetHistory(cropId, days);
        return history is null ? NotFound() : Ok(history.Prices);
    }
}
