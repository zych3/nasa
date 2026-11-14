namespace FieldShift.Web.DTOs;

/// <summary>A parcel near a point. <see cref="Address"/> is null for the parcel at the point itself.</summary>
public sealed record NearbyParcelResponse(
    string ParcelId,
    double Latitude,
    double Longitude,
    string GeometryWkt,
    string? Address,
    double DistanceMeters);
