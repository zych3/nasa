using FieldShift.Web.Countries;
using FieldShift.Web.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ParcelsController(ICountryProvider country, ILogger<ParcelsController> logger) : ControllerBase
{
    [HttpGet("search")]
    public async Task<ActionResult<ParcelSearchResponse>> Search([FromQuery] string? address)
    {
        if (string.IsNullOrWhiteSpace(address) || address.Length > 200)
        {
            return Problem("Address is required (max 200 characters).", statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            var geocode = await country.GetGeocodeAsync(address);
            if (geocode is null)
            {
                return Problem("Address not found.", statusCode: StatusCodes.Status404NotFound);
            }

            var parcel = await country.GetParcelAsync(geocode);
            if (parcel is null)
            {
                return Problem("No parcel at this address.", statusCode: StatusCodes.Status404NotFound);
            }

            return new ParcelSearchResponse(parcel.Id, geocode.Latitude, geocode.Longitude, parcel.GeometryWkt);
        }
        catch (TaskCanceledException ex)
        {
            logger.LogWarning(ex, "Parcel lookup timed out");
            return Problem("Upstream service timed out.", statusCode: StatusCodes.Status504GatewayTimeout);
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "Parcel lookup failed");
            return Problem("Upstream service error.", statusCode: StatusCodes.Status502BadGateway);
        }
    }
}
