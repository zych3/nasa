using System.Text.Json;

namespace FieldShift.Web.DTOs;

/// <summary>A plan the logged-in user keeps. <see cref="Plan"/> is the plan object exactly as <c>POST /api/recommendations</c> returned it.</summary>
public sealed record SavePlanRequest
{
    /// <summary>Parcel the plan is for (optional); the location is <see cref="Lat"/>/<see cref="Lon"/>.</summary>
    public string? ParcelId { get; init; }

    public double? Lat { get; init; }
    public double? Lon { get; init; }

    /// <summary>"balanced", "soil_health" or "safe_harvest": the goal whose plan was chosen.</summary>
    public string? Goal { get; init; }

    /// <summary>The chosen plan (a <c>best</c> or an element of <c>alternatives</c>); must have a <c>cycle</c> array.</summary>
    public JsonElement? Plan { get; init; }

    /// <summary>Optional: the answers the plan was made from (the request body sent to <c>/api/recommendations</c>).</summary>
    public JsonElement? Answers { get; init; }
}

public sealed record SavedPlanResponse
{
    public required Guid Id { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
    public string? ParcelId { get; init; }
    public required double Lat { get; init; }
    public required double Lon { get; init; }
    public required string Goal { get; init; }
    public required JsonElement Plan { get; init; }
    public JsonElement? Answers { get; init; }
}
