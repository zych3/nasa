namespace FieldShift.Web.DTOs;

/// <summary>What the farmer tells us. Only <see cref="Lat"/> and <see cref="Lon"/> are required.</summary>
public sealed record RecommendationRequest
{
    /// <summary>Parcel the answer is for (echoed back); the location comes from <see cref="Lat"/>/<see cref="Lon"/>.</summary>
    public string? ParcelId { get; init; }

    public double? Lat { get; init; }
    public double? Lon { get; init; }

    /// <summary>Crops grown on the plot in earlier years, most recent first (up to 10; empty or missing when nothing was grown before). Crop ids from <c>GET /api/crops</c>.</summary>
    public IReadOnlyList<string>? PastCrops { get; init; }

    /// <summary>Optional goal: "balanced" (default), "soil_health" or "safe_harvest".</summary>
    public string? Goal { get; init; }

    public IReadOnlyList<string>? ExcludedCrops { get; init; }

    public bool? HasLivestock { get; init; }

    public bool? HasIrrigation { get; init; }

    /// <summary>Optional: soil pH measured in KCl (from a soil test). Plausible range 3–9.</summary>
    public double? SoilPhKCl { get; init; }
}

/// <summary>Rotation plans for one plot. Texts are codes; the frontend translates them.</summary>
public sealed record RecommendationResponse
{
    public string? ParcelId { get; init; }

    /// <summary>"ok", or "no_plan" when no crop suits the plot (see <see cref="Warnings"/>).</summary>
    public required string Status { get; init; }

    /// <summary>Goal the main plan was chosen for: "balanced", "soil_health" or "safe_harvest".</summary>
    public required string MainGoal { get; init; }

    /// <summary>One entry per goal. The entry whose goal equals <see cref="MainGoal"/> is the main recommendation.</summary>
    public required IReadOnlyList<GoalRecommendation> Recommendations { get; init; }

    public required IReadOnlyList<RecommendationWarning> Warnings { get; init; }

    public required IReadOnlyList<RecommendationInput> Inputs { get; init; }

    public required DateTimeOffset GeneratedAtUtc { get; init; }
}

public sealed record GoalRecommendation
{
    public required string Goal { get; init; }
    public required RotationPlanDto Best { get; init; }
    public required IReadOnlyList<RotationPlanDto> Alternatives { get; init; }
}

public sealed record RotationPlanDto
{
    /// <summary>Years before the repeating cycle starts (bridge years after the history); usually 0 or 1 entries.</summary>
    public required IReadOnlyList<PlanSeasonDto> Transition { get; init; }

    public required IReadOnlyList<PlanSeasonDto> Cycle { get; init; }

    public required int CycleYears { get; init; }

    /// <summary>All objectives, each 0–1 (higher is better).</summary>
    public required IReadOnlyList<PlanScoreDto> Scores { get; init; }

    /// <summary>Strongest reasons behind the plan (codes with numbers).</summary>
    public required IReadOnlyList<PlanReasonDto> Reasons { get; init; }

    /// <summary>False when a hard rule is broken (e.g. same crop too often); the codes are in <see cref="Problems"/>.</summary>
    public required bool IsFeasible { get; init; }

    public required IReadOnlyList<string> Problems { get; init; }
}

public sealed record PlanSeasonDto
{
    public required int HarvestYear { get; init; }
    public required CropRef Crop { get; init; }

    public CropRef? CatchCrop { get; init; }

    /// <summary>Modelled chance of a good harvest, 0–1, with a level.</summary>
    public required RatingDto Harvest { get; init; }
}

public sealed record CropRef
{
    public required string Id { get; init; }

    public required IReadOnlyDictionary<string, string> Name { get; init; }

    /// <summary>Id in the crop catalogue (<c>GET /api/crops</c>) when the crop is there, so the frontend can show its photo.</summary>
    public string? CatalogId { get; init; }

    /// <summary>When to sow, as days of the year (1-366). Winter crops are sown the year before harvest: see <see cref="SownPreviousYear"/>.</summary>
    public required DayRange Sow { get; init; }

    /// <summary>When the crop is harvested, as days of the year (1-366), in the harvest year.</summary>
    public required DayRange Harvest { get; init; }

    public required bool SownPreviousYear { get; init; }
}

public sealed record DayRange(int From, int To);

public sealed record RatingDto
{
    public required double Value { get; init; }

    /// <summary>"good", "ok" or "poor".</summary>
    public required string Level { get; init; }
}

public sealed record PlanScoreDto
{
    /// <summary>"harvest", "humus", "disease", "nitrogen", "cover", "structure" or "water".</summary>
    public required string Key { get; init; }
    public required RatingDto Rating { get; init; }
}

public sealed record PlanReasonDto
{
    /// <summary>Engine reason code, e.g. "effect.humusC".</summary>
    public required string Code { get; init; }
    public string? CropId { get; init; }
    public string? Var { get; init; }

    /// <summary>Sign tells the direction (positive raises the variable, negative lowers it).</summary>
    public required double Delta { get; init; }
}

public sealed record RecommendationWarning
{
    /// <summary>Soil: "soil_unavailable" (SoilGrids request failed), "soil_no_data" (nothing for this spot) or "soil_partial"
    /// (some values missing; subject = comma-separated "sand", "clay", "silt", "ph", "soc"); in all three typical Polish values fill the gaps.
    /// Also "few_crops_fit", "crop_not_supported", "no_plan_for_goal" (no plan for that goal, subject = goal)
    /// or "goal_unavailable" (the asked-for goal has no plan, so <c>mainGoal</c> is another one; subject = asked goal).</summary>
    public required string Code { get; init; }

    public string? Subject { get; init; }
}

public sealed record RecommendationInput
{
    /// <summary>"climate", "soil", "history", "farmer".</summary>
    public required string Key { get; init; }

    /// <summary>"satellite" (NASA), "model" (computer model on real data, e.g. SoilGrids), "estimated" (assumed, no data) or "user_answer".</summary>
    public required string Origin { get; init; }
}
