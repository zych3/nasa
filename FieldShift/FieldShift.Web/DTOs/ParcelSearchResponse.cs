namespace FieldShift.Web.DTOs;

public sealed record ParcelSearchResponse(string ParcelId, double Latitude, double Longitude, string GeometryWkt);
