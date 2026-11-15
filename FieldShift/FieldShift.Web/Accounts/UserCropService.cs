using FieldShift.Web.Data;
using FieldShift.Web.DTOs;
using FieldShift.Web.Repositories;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

/// <summary>Error codes of <c>/api/my-crops</c> (the frontend translates them).</summary>
public static class UserCropErrorCodes
{
    public const string InvalidCrop = "invalid_crop";
    public const string InvalidLocation = "invalid_location";
    public const string LabelTooLong = "label_too_long";
    public const string TooManyCrops = "too_many_crops";
    public const string NotFound = "not_found";
}

public sealed record UserCropResult(UserCrop? Crop, string? ErrorCode)
{
    public static UserCropResult Fail(string code) => new(null, code);
}

/// <summary>
/// The logged-in user's saved crops (<see cref="UserCrop"/>). Every call is scoped to one user id: an entry of
/// another user is "not found".
/// </summary>
public sealed class UserCropService(
    IDbContextFactory<AccountsDbContext> contexts,
    AccountsSchema schema,
    TimeProvider time)
{
    public const int MaxCropsPerUser = 100;
    public const int MaxLabelLength = 200;
    private const int MaxParcelIdLength = 100;

    /// <summary>Newest first.</summary>
    public async Task<IReadOnlyList<UserCrop>> ListAsync(Guid userId, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);
        return await db.Crops.AsNoTracking()
            .Where(c => c.UserId == userId)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync(ct);
    }

    public async Task<UserCrop?> GetAsync(Guid userId, Guid id, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);
        return await db.Crops.AsNoTracking().SingleOrDefaultAsync(c => c.UserId == userId && c.Id == id, ct);
    }

    public async Task<UserCropResult> CreateAsync(Guid userId, UserCropCreateRequest request, CancellationToken ct)
    {
        if (!IsKnownCrop(request.CropId))
        {
            return UserCropResult.Fail(UserCropErrorCodes.InvalidCrop);
        }

        if (!IsValidPoint(request.Latitude, request.Longitude))
        {
            return UserCropResult.Fail(UserCropErrorCodes.InvalidLocation);
        }

        var lat = request.Latitude!.Value;
        var lon = request.Longitude!.Value;

        var parcelId = Clean(request.ParcelId);
        if (parcelId is { Length: > MaxParcelIdLength })
        {
            return UserCropResult.Fail(UserCropErrorCodes.InvalidLocation);
        }

        var label = Clean(request.Label);
        if (label is { Length: > MaxLabelLength })
        {
            return UserCropResult.Fail(UserCropErrorCodes.LabelTooLong);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        if (await db.Crops.CountAsync(c => c.UserId == userId, ct) >= MaxCropsPerUser)
        {
            return UserCropResult.Fail(UserCropErrorCodes.TooManyCrops);
        }

        var now = time.GetUtcNow();
        var crop = new UserCrop
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CropId = request.CropId!.Trim(),
            Latitude = lat,
            Longitude = lon,
            ParcelId = parcelId,
            Label = label,
            IsActive = request.IsActive ?? true,
            CreatedAt = now,
            UpdatedAt = now,
        };
        db.Crops.Add(crop);
        await db.SaveChangesAsync(ct);
        return new UserCropResult(crop, null);
    }

    public async Task<UserCropResult> UpdateAsync(
        Guid userId, Guid id, UserCropUpdateRequest request, CancellationToken ct)
    {
        if (request.CropId is not null && !IsKnownCrop(request.CropId))
        {
            return UserCropResult.Fail(UserCropErrorCodes.InvalidCrop);
        }

        // A new place needs both coordinates.
        var movesPlace = request.Latitude is not null || request.Longitude is not null;
        if (movesPlace && !IsValidPoint(request.Latitude, request.Longitude))
        {
            return UserCropResult.Fail(UserCropErrorCodes.InvalidLocation);
        }

        var parcelId = Clean(request.ParcelId);
        if (parcelId is { Length: > MaxParcelIdLength })
        {
            return UserCropResult.Fail(UserCropErrorCodes.InvalidLocation);
        }

        var label = Clean(request.Label);
        if (label is { Length: > MaxLabelLength })
        {
            return UserCropResult.Fail(UserCropErrorCodes.LabelTooLong);
        }

        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);

        var crop = await db.Crops.SingleOrDefaultAsync(c => c.UserId == userId && c.Id == id, ct);
        if (crop is null)
        {
            return UserCropResult.Fail(UserCropErrorCodes.NotFound);
        }

        if (request.CropId is not null)
        {
            crop.CropId = request.CropId.Trim();
        }

        if (movesPlace)
        {
            crop.Latitude = request.Latitude!.Value;
            crop.Longitude = request.Longitude!.Value;
        }

        if (request.ParcelId is not null)
        {
            crop.ParcelId = parcelId;
        }

        if (request.Label is not null)
        {
            crop.Label = label;
        }

        if (request.IsActive is { } active)
        {
            crop.IsActive = active;
        }

        crop.UpdatedAt = time.GetUtcNow();
        await db.SaveChangesAsync(ct);
        return new UserCropResult(crop, null);
    }

    public static UserCropResponse ToResponse(UserCrop c) => new()
    {
        Id = c.Id,
        CropId = c.CropId,
        Latitude = c.Latitude,
        Longitude = c.Longitude,
        ParcelId = c.ParcelId,
        Label = c.Label,
        IsActive = c.IsActive,
        CreatedAt = c.CreatedAt,
        UpdatedAt = c.UpdatedAt,
    };

    private static bool IsValidPoint(double? lat, double? lon) =>
        lat is { } la && double.IsFinite(la) && la is >= -90 and <= 90
        && lon is { } lo && double.IsFinite(lo) && lo is >= -180 and <= 180;

    private static bool IsKnownCrop(string? cropId) =>
        !string.IsNullOrWhiteSpace(cropId) && CropCatalog.ById.ContainsKey(new CropId(cropId.Trim()));

    /// <summary>Trimmed; null when empty.</summary>
    private static string? Clean(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}