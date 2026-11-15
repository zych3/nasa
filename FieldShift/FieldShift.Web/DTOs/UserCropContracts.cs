namespace FieldShift.Web.DTOs;

/// <summary>Body of <c>POST /api/my-crops</c>: one crop at one place.</summary>
public sealed record UserCropCreateRequest
{
    /// <summary>Crop id from <c>GET /api/crops</c>, e.g. "wheat". Required.</summary>
    public string? CropId { get; init; }

    /// <summary>Required, -90 to 90.</summary>
    public double? Latitude { get; init; }

    /// <summary>Required, -180 to 180.</summary>
    public double? Longitude { get; init; }

    /// <summary>The registered parcel at the place, when one was chosen.</summary>
    public string? ParcelId { get; init; }

    /// <summary>The user's words for the place, e.g. the address. At most 200 characters.</summary>
    public string? Label { get; init; }

    /// <summary>Default true.</summary>
    public bool? IsActive { get; init; }
}

/// <summary>Body of <c>PATCH /api/my-crops/{id}</c>: only the fields that are sent change.</summary>
public sealed record UserCropUpdateRequest
{
    public string? CropId { get; init; }

    /// <summary>New place: send together with <see cref="Longitude"/>.</summary>
    public double? Latitude { get; init; }

    public double? Longitude { get; init; }

    /// <summary>The parcel at the new place; an empty string removes it.</summary>
    public string? ParcelId { get; init; }

    /// <summary>An empty string removes the label.</summary>
    public string? Label { get; init; }

    public bool? IsActive { get; init; }
}

/// <summary>One saved crop of the logged-in user.</summary>
public sealed record UserCropResponse
{
    public required Guid Id { get; init; }

    public required string CropId { get; init; }

    public required double Latitude { get; init; }

    public required double Longitude { get; init; }

    public string? ParcelId { get; init; }

    public string? Label { get; init; }

    public required bool IsActive { get; init; }

    public required DateTimeOffset CreatedAt { get; init; }

    public required DateTimeOffset UpdatedAt { get; init; }
}