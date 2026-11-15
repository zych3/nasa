using System.Text.Json;

namespace FieldShift.Web.ClimateTrends;

/// <summary>
/// When a trend is shown and what advice goes with it: the content of <c>Data/climate-trend-rules.json</c>.
/// The thresholds are the team's choice (see the file), kept as data so they can change without code.
/// </summary>
public sealed record ClimateTrendRules
{
    public const string FileName = "climate-trend-rules.json";

    /// <summary>A shorter series cannot tell a climate trend from a few odd years.</summary>
    public required int MinYears { get; init; }

    /// <summary>Mann–Kendall p-value a trend must stay below.</summary>
    public required double MaxPValue { get; init; }

    /// <summary>Length of the first and the last period whose means are compared.</summary>
    public required int ComparedYears { get; init; }

    public required int MaxTrends { get; init; }

    public required IReadOnlyList<IndicatorRule> Indicators { get; init; }

    public required LightSoilRule LightSoil { get; init; }

    public required IReadOnlyList<AdviceRule> Advice { get; init; }

    /// <summary>Reads and checks the rules; throws when the file is missing or does not make sense.</summary>
    public static ClimateTrendRules Load(string path)
    {
        var rules = JsonSerializer.Deserialize<ClimateTrendRules>(
                File.ReadAllText(path), new JsonSerializerOptions(JsonSerializerDefaults.Web))
            ?? throw new InvalidOperationException($"{path} is empty.");
        rules.Validate();
        return rules;
    }

    public static ClimateTrendRules LoadDefault() =>
        Load(Path.Combine(AppContext.BaseDirectory, "Data", FileName));

    private void Validate()
    {
        if (MinYears < 2 * ComparedYears || ComparedYears < 1)
            throw new InvalidOperationException("minYears must cover two periods of comparedYears.");
        if (MaxPValue is <= 0 or > 1 || MaxTrends < 1)
            throw new InvalidOperationException("maxPValue must be in (0, 1] and maxTrends at least 1.");

        var known = YearlyIndicators.All.Select(i => i.Id).ToHashSet();
        foreach (var rule in Indicators)
        {
            if (!known.Contains(rule.Id))
                throw new InvalidOperationException($"Unknown indicator '{rule.Id}' in the trend rules.");
            if (rule.MinChange is null == rule.MinChangePercent is null)
                throw new InvalidOperationException($"Indicator '{rule.Id}' needs exactly one of minChange and minChangePercent.");
            if (rule.MinChange is <= 0 || rule.MinChangePercent is <= 0)
                throw new InvalidOperationException($"Indicator '{rule.Id}' needs a positive threshold.");
        }

        if (Indicators.Select(r => r.Id).Distinct().Count() != Indicators.Count)
            throw new InvalidOperationException("An indicator is listed twice in the trend rules.");

        var changes = Indicators.SelectMany(r => new[] { r.WhenUp, r.WhenDown }).ToHashSet();
        foreach (var advice in Advice.Where(a => !changes.Contains(a.Change)))
            throw new InvalidOperationException($"Advice for '{advice.Change}', which no indicator produces.");
    }
}

/// <param name="Id">Indicator id from <see cref="YearlyIndicators.All"/>.</param>
/// <param name="Group">Indicators of one group describe the same thing; one trend is shown for them.</param>
/// <param name="WhenUp">What a rise means, e.g. "drier".</param>
/// <param name="WhenDown">What a fall means.</param>
/// <param name="MinChange">Smallest difference of the two period means worth showing, in the indicator's unit.</param>
/// <param name="MinChangePercent">The same as a percentage of the first period's mean.</param>
public sealed record IndicatorRule(
    string Id, string Group, string WhenUp, string WhenDown, double? MinChange = null, double? MinChangePercent = null);

public sealed record LightSoilRule
{
    public IReadOnlyList<string> TextureCodes { get; init; } = [];
    public IReadOnlyList<string> Complexes { get; init; } = [];
}

public sealed record AdviceRule
{
    public required string Change { get; init; }

    /// <summary>Advice that always applies.</summary>
    public IReadOnlyList<string> Codes { get; init; } = [];

    /// <summary>Added only when the parcel is known to have light soil.</summary>
    public IReadOnlyList<string> OnLightSoil { get; init; } = [];

    /// <summary>Added only when the parcel's slope is known and at least <see cref="SlopeAtLeastPct"/>.</summary>
    public IReadOnlyList<string> OnSlope { get; init; } = [];

    public double? SlopeAtLeastPct { get; init; }

    /// <summary>Added unless the last spring frost itself clearly comes earlier.</summary>
    public IReadOnlyList<string> UnlessEarlierSpringFrost { get; init; } = [];
}
