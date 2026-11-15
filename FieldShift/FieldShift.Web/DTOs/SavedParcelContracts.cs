using System.Text.Json;

namespace FieldShift.Web.DTOs;

/// <summary>
/// One parcel in the user's "My parcels" list, as the app sends it. <see cref="Parcel"/> is the parcel object the app
/// keeps (id, centre, outline, address); the server stores it as it is. <see cref="Deleted"/> = the user removed it
/// (kept as a marker so the user's other devices remove it too).
/// </summary>
public sealed record SyncParcelItem
{
    public string? ParcelId { get; init; }

    /// <summary>The parcel object; required unless <see cref="Deleted"/>.</summary>
    public JsonElement? Parcel { get; init; }

    /// <summary>When the user last changed this parcel (added or removed it), set by the app. The newer one wins.</summary>
    public DateTimeOffset? UpdatedAt { get; init; }

    public bool Deleted { get; init; }
}

public sealed record SyncParcelsRequest
{
    /// <summary>Everything the device has: live parcels and removals. May be empty (a new device just loads).</summary>
    public List<SyncParcelItem>? Items { get; init; }
}

public sealed record SyncParcelsResponse
{
    /// <summary>Server time of this sync.</summary>
    public required DateTimeOffset SyncedAt { get; init; }

    /// <summary>The merged list: live parcels and removals the device has to apply.</summary>
    public required IReadOnlyList<SyncParcelItem> Items { get; init; }
}
