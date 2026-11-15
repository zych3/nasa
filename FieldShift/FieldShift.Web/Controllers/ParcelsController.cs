using FieldShift.Web.Countries;
using System.Text.Json;
using FieldShift.Web.Data;
using FieldShift.Web.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace FieldShift.Web.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ParcelsController(
    ICountryProvider country,
    IAddressSuggester suggester,
    ILogger<ParcelsController> logger) : ControllerBase
{
    private const int SuggestLimit = 8;
    private const int SuggestMinLength = 3;

    /// <summary>
    /// Address hints while the user types (search-as-you-type). Empty list for short input
    /// or when nothing matches; never an error, so typing is never interrupted.
    /// </summary>
    [HttpGet("suggest")]
    public async Task<ActionResult<IReadOnlyList<AddressSuggestion>>> Suggest(
        [FromQuery] string? q, CancellationToken ct)
    {
        var text = q?.Trim() ?? "";
        if (text.Length < SuggestMinLength || text.Length > 200)
        {
            return Array.Empty<AddressSuggestion>();
        }

        return Ok(await suggester.SuggestAsync(text, SuggestLimit, ct));
    }

    /// <summary>The parcel at a point (e.g. a chosen address hint).</summary>
    [HttpGet("at")]
    public async Task<ActionResult<ParcelSearchResponse>> At([FromQuery] double? lat, [FromQuery] double? lon)
    {
        if (lat is not (>= -90 and <= 90) || lon is not (>= -180 and <= 180))
        {
            return Problem("Valid lat and lon are required.", statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            var parcel = await country.GetParcelAsync(new GeocodeResult(null, null, null, lat.Value, lon.Value, null));
            if (parcel is null)
            {
                return Problem("No parcel at this point.", statusCode: StatusCodes.Status404NotFound);
            }

            return new ParcelSearchResponse(parcel.Id, lat.Value, lon.Value, parcel.GeometryWkt);
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

    private const int NearbyAddressLimit = 8;
    private const int NearbyRadiusMeters = 300;

    /// <summary>
    /// Parcels around a point: the parcel at the point itself plus the parcels of the
    /// nearest address points. Distinct, nearest first.
    /// </summary>
    [HttpGet("nearby")]
    public async Task<ActionResult<IReadOnlyList<NearbyParcelResponse>>> Nearby(
        [FromQuery] double? lat, [FromQuery] double? lon)
    {
        if (lat is not (>= -90 and <= 90) || lon is not (>= -180 and <= 180))
        {
            return Problem("Valid lat and lon are required.", statusCode: StatusCodes.Status400BadRequest);
        }

        IReadOnlyList<GeocodeResult> addresses;
        try
        {
            addresses = await country.GetNearbyAddressesAsync(lat.Value, lon.Value, NearbyAddressLimit, NearbyRadiusMeters);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            // Still try the parcel at the point itself.
            logger.LogWarning(ex, "Reverse geocoding failed");
            addresses = [];
        }

        var here = new GeocodeResult(null, null, null, lat.Value, lon.Value, null);
        var lookups = addresses.Prepend(here).Select(async location =>
        {
            try
            {
                var parcel = await country.GetParcelAsync(location);
                return parcel is null ? null : new NearbyParcelResponse(
                    parcel.Id,
                    location.Latitude,
                    location.Longitude,
                    parcel.GeometryWkt,
                    Label(location),
                    DistanceMeters(lat.Value, lon.Value, location.Latitude, location.Longitude));
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
            {
                logger.LogWarning(ex, "Parcel lookup failed for nearby point");
                return null;
            }
        });

        var parcels = (await Task.WhenAll(lookups))
            .OfType<NearbyParcelResponse>()
            .OrderBy(p => p.DistanceMeters)
            .GroupBy(p => p.ParcelId)
            // Keep the nearest hit, but prefer one that has an address label.
            .Select(g => g.FirstOrDefault(p => p.Address is not null) is { } named
                ? named with { DistanceMeters = g.First().DistanceMeters }
                : g.First())
            .OrderBy(p => p.DistanceMeters)
            .ToList();

        return parcels;
    }

    private static string? Label(GeocodeResult a) =>
        a.Street is null ? a.Municipality
        : a.Municipality is null || a.Street.StartsWith(a.Municipality) ? a.Street
        : $"{a.Street}, {a.Municipality}";

    private static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double earthRadius = 6_371_000;
        static double Rad(double deg) => deg * Math.PI / 180;
        var dLat = Rad(lat2 - lat1);
        var dLon = Rad(lon2 - lon1);
        var h = Math.Pow(Math.Sin(dLat / 2), 2) +
                Math.Cos(Rad(lat1)) * Math.Cos(Rad(lat2)) * Math.Pow(Math.Sin(dLon / 2), 2);
        return 2 * earthRadius * Math.Asin(Math.Sqrt(h));
    }
}
