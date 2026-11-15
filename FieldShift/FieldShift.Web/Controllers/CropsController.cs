using FieldShift.Web.Data;
using FieldShift.Web.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/crops")]
public class CropsController(ICropRepository crops) : ControllerBase
{
    /// <summary>Crop catalogue: names, Wikipedia photo and links, Polish area and yield, growing traits.</summary>
    [HttpGet]
    public ActionResult<IReadOnlyList<Crop>> GetAll() => Ok(crops.GetAll());

    [HttpGet("{id}")]
    public ActionResult<Crop> GetById(string id) =>
        crops.GetById(new CropId(id)) is { } crop ? Ok(crop) : NotFound();
}
