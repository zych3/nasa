using System.Text.Json;
using FieldShift.Web.DTOs;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

public static class SavedParcelErrorCodes
{
    public const string InvalidParcels = "invalid_parcels";
    public const string TooManyParcels = "too_many_parcels";
}

/// <summary>What "My parcels" may look like and how two copies of the list are merged.</summary>
public static class SavedParcelRules
{
    public const int MaxParcelsPerUser = 100;

    /// <summary>Removals count too, so a device cannot send an endless list.</summary>
    public const int MaxItemsPerSync = 300;

    public const int MaxParcelChars = 64 * 1024;
    public const int MaxParcelIdChars = 100;

    /// <summary>How long a removal is remembered for the user's other devices.</summary>
    public static readonly TimeSpan RemovalMemory = TimeSpan.FromDays(90);

    /// <summary>The error code for a bad request, or null when it can be merged.</summary>
    public static string? Validate(SyncParcelsRequest request)
    {
        var items = request.Items ?? [];
        if (items.Count > MaxItemsPerSync)
        {
            return SavedParcelErrorCodes.TooManyParcels;
        }

        var seen = new HashSet<string>();
        foreach (var item in items)
        {
            if (string.IsNullOrWhiteSpace(item.ParcelId) || item.ParcelId.Length > MaxParcelIdChars
                || item.UpdatedAt is null || !seen.Add(item.ParcelId))
            {
                return SavedParcelErrorCodes.InvalidParcels;
            }

            if (!item.Deleted
                && (item.Parcel is not { ValueKind: JsonValueKind.Object } parcel
                    || parcel.GetRawText().Length > MaxParcelChars))
            {
                return SavedParcelErrorCodes.InvalidParcels;
            }
        }

        return items.Count(i => !i.Deleted) > MaxParcelsPerUser ? SavedParcelErrorCodes.TooManyParcels : null;
    }

    /// <summary>
    /// Last write wins: the item replaces the stored copy only when it is newer (a tie keeps the stored one).
    /// A time in the future (a wrong clock) counts as <paramref name="now"/>. Returns true when the copy changed.
    /// </summary>
    public static bool Apply(SavedParcel stored, SyncParcelItem item, DateTimeOffset now)
    {
        var at = item.UpdatedAt!.Value;
        if (at > now)
        {
            at = now;
        }

        if (at <= stored.UpdatedAt)
        {
            return false;
        }

        stored.UpdatedAt = at;
        stored.IsDeleted = item.Deleted;
        if (!item.Deleted)
        {
            stored.DataJson = item.Parcel!.Value.GetRawText();
        }

        return true;
    }
}

public sealed class SavedParcelService(
    IDbContextFactory<AccountsDbContext> contexts,
    AccountsSchema schema,
    TimeProvider time)
{
    /// <summary>
    /// Merges the device's list into the user's stored list and returns the result. Null when the merge would leave
    /// the user with more than <see cref="SavedParcelRules.MaxParcelsPerUser"/> parcels.
    /// </summary>
    public async Task<SyncParcelsResponse?> SyncAsync(Guid userId, SyncParcelsRequest request, CancellationToken ct)
    {
        await schema.EnsureAppliedAsync(ct);
        await using var db = await contexts.CreateDbContextAsync(ct);
        var now = time.GetUtcNow();

        var stored = await db.SavedParcels.Where(p => p.UserId == userId).ToDictionaryAsync(p => p.ParcelId, ct);
        foreach (var item in request.Items ?? [])
        {
            if (stored.TryGetValue(item.ParcelId!, out var existing))
            {
                SavedParcelRules.Apply(existing, item, now);
                continue;
            }

            var created = new SavedParcel
            {
                UserId = userId,
                ParcelId = item.ParcelId!,
                DataJson = item.Deleted ? "{}" : item.Parcel!.Value.GetRawText(),
                UpdatedAt = item.UpdatedAt!.Value > now ? now : item.UpdatedAt!.Value,
                IsDeleted = item.Deleted,
            };
            db.SavedParcels.Add(created);
            stored[created.ParcelId] = created;
        }

        if (stored.Values.Count(p => !p.IsDeleted) > SavedParcelRules.MaxParcelsPerUser)
        {
            return null;
        }

        // Old removals have reached every device by now.
        var forgotten = stored.Values.Where(p => p.IsDeleted && p.UpdatedAt < now - SavedParcelRules.RemovalMemory).ToList();
        foreach (var p in forgotten)
        {
            db.SavedParcels.Remove(p); // an entry added just now is simply dropped
            stored.Remove(p.ParcelId);
        }

        await db.SaveChangesAsync(ct);
        return new SyncParcelsResponse
        {
            SyncedAt = now,
            Items = stored.Values.OrderByDescending(p => p.UpdatedAt).Select(ToItem).ToList(),
        };
    }

    private static SyncParcelItem ToItem(SavedParcel parcel) => new()
    {
        ParcelId = parcel.ParcelId,
        UpdatedAt = parcel.UpdatedAt,
        Deleted = parcel.IsDeleted,
        Parcel = parcel.IsDeleted ? null : JsonDocument.Parse(parcel.DataJson).RootElement.Clone(),
    };
}
