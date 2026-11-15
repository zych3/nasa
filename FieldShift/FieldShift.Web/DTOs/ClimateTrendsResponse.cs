namespace FieldShift.Web.DTOs;

/// <summary>
/// Clear long-term climate changes in the area of a parcel, with long-term options for each. These are facts
/// about past years, not a forecast.
/// </summary>
public sealed record ClimateTrendsResponse
{
    /// <summary>Parcel the point lies on; null when no parcel was found and the raw point was used.</summary>
    public string? ParcelId { get; init; }

    public required double Lat { get; init; }
    public required double Lon { get; init; }

    /// <summary>
    /// "ok" (trends found), "no_clear_trends" (enough data, nothing clear enough to show) or "no_data"
    /// (the series is too short).
    /// </summary>
    public required string Status { get; init; }

    public required int FromYear { get; init; }
    public required int ToYear { get; init; }

    /// <summary>Width of one cell of the climate grid in km: the values describe the area, not the field.</summary>
    public required int GridKm { get; init; }

    public required string Source { get; init; }

    /// <summary>"estimated": a weather model corrected with satellite and station measurements.</summary>
    public required string SourceKind { get; init; }

    /// <summary>Cautions about the data, e.g. "regional_climate_grid"; the frontend translates them.</summary>
    public required IReadOnlyList<string> NoteCodes { get; init; }

    /// <summary>What is known about the parcel and was used to fit the advice.</summary>
    public required ClimateTrendSite Site { get; init; }

    /// <summary>At most three trends, the most certain first. Empty unless <see cref="Status"/> is "ok".</summary>
    public required IReadOnlyList<ClimateTrendResponse> Trends { get; init; }

    /// <summary>Every indicator that was checked and why it is or is not among the trends: for transparency.</summary>
    public required IReadOnlyList<ClimateIndicatorCheck> Considered { get; init; }
}

/// <param name="Id">Indicator id.</param>
/// <param name="Outcome">
/// "shown", "merged" (named in another trend's <c>alsoSeenIn</c>), "too_short", "not_significant",
/// "below_threshold" (clear but too small to matter), "inconsistent" or "over_limit".
/// </param>
/// <param name="PValue">Mann–Kendall p-value; null when the series was too short.</param>
/// <param name="EarlyMean">Mean of the first compared years.</param>
/// <param name="RecentMean">Mean of the last compared years.</param>
public sealed record ClimateIndicatorCheck(string Id, string Outcome, double? PValue, double? EarlyMean, double? RecentMean);

/// <param name="Soil">"light", "other", or null when the soil map gave nothing for the parcel.</param>
/// <param name="SlopePct">Mean slope of the parcel in %; null when unknown.</param>
public sealed record ClimateTrendSite(string? Soil, double? SlopePct);

public sealed record ClimateTrendResponse
{
    /// <summary>The indicator shown, e.g. "hot_days", "frost_free_days", "longest_dry_spell".</summary>
    public required string Id { get; init; }

    /// <summary>What the change means, e.g. "more_heat", "drier", "longer_frost_free".</summary>
    public required string Change { get; init; }

    /// <summary>"up" or "down".</summary>
    public required string Direction { get; init; }

    /// <summary>"days", "day_of_year", "celsius", "degree_days" or "millimetres".</summary>
    public required string Unit { get; init; }

    /// <summary>Mean of the years <see cref="EarlyFrom"/>–<see cref="EarlyTo"/>.</summary>
    public required double EarlyMean { get; init; }

    /// <summary>Mean of the years <see cref="RecentFrom"/>–<see cref="RecentTo"/>.</summary>
    public required double RecentMean { get; init; }

    public required int EarlyFrom { get; init; }
    public required int EarlyTo { get; init; }
    public required int RecentFrom { get; init; }
    public required int RecentTo { get; init; }

    /// <summary>Chance of seeing such a trend in a climate that does not change (Mann–Kendall test).</summary>
    public required double PValue { get; init; }

    /// <summary>Other indicators that show the same change and were merged into this trend.</summary>
    public required IReadOnlyList<string> AlsoSeenIn { get; init; }

    /// <summary>Long-term options to consider; the frontend translates them. May be empty.</summary>
    public required IReadOnlyList<string> AdviceCodes { get; init; }

    /// <summary>Years that have a value, and the values: for a chart only.</summary>
    public required IReadOnlyList<int> Years { get; init; }

    public required IReadOnlyList<double> Values { get; init; }
}
