using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/crops")]
public class CropsController(
    ICropRepository crops, CropPriceService prices, PricesSchema schema, ILogger<CropsController> log)
    : ControllerBase
{
    /// <summary>Crop catalogue: names, Wikipedia photo and links, Polish area and yield, growing traits.</summary>
    [HttpGet]
    public Task<ActionResult<IReadOnlyList<Crop>>> GetAll(CancellationToken ct) =>
        WithDatabase<IReadOnlyList<Crop>>(ct, async () => Ok(crops.GetAll(await prices.GetSummariesAsync(ct))));

    [HttpGet("{id}")]
    public Task<ActionResult<Crop>> GetById(string id, CancellationToken ct) =>
        WithDatabase<Crop>(ct, async () =>
        {
            var cropId = new CropId(id);
            if (!CropCatalog.ById.ContainsKey(cropId))
            {
                return NotFound();
            }
            return crops.GetById(cropId, await prices.GetSummariesAsync(ct)) is { } crop ? Ok(crop) : NotFound();
        });

    /// <summary>
    /// The latest <paramref name="count"/> real prices per tonne, oldest first. Served from the database;
    /// the source (GUS) is only called when the stored prices are stale.
    /// Crops without published prices return <c>status: "no_data"</c> and an empty list.
    /// </summary>
    [HttpGet("{id}/prices")]
    public Task<ActionResult<PriceHistory>> GetPrices(
        string id, CancellationToken ct, [FromQuery] int count = CropPriceService.DefaultCount)
    {
        if (count is < 1 or > CropPriceService.MaxCount)
        {
            return Task.FromResult<ActionResult<PriceHistory>>(Problem(
                statusCode: StatusCodes.Status400BadRequest,
                detail: $"'count' must be between 1 and {CropPriceService.MaxCount}."));
        }

        return WithDatabase<PriceHistory>(ct, async () =>
            await prices.GetLatestAsync(new CropId(id), count, ct) is { } history ? Ok(history) : NotFound());
    }

    /// <summary>503 when the price database cannot be reached; the frontend then uses its saved copy.</summary>
    private async Task<ActionResult<T>> WithDatabase<T>(CancellationToken ct, Func<Task<ActionResult<T>>> action)
    {
        try
        {
            await schema.EnsureAppliedAsync(ct);
            return await action();
        }
        catch (Exception e) when (PricesDbContext.IsDatabaseFailure(e))
        {
            log.LogError(e, "Price database is not available");
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                detail: "The price database is not available.");
        }
    }
}
