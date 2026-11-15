using FieldShift.Web.DTOs;
using FieldShift.Web.FieldProfile;

namespace FieldShift.Web.ClimateTrends;

/// <summary>What is known about the parcel; null = not known (then only general advice is given).</summary>
public sealed record SiteConditions(bool? LightSoil, double? SlopePct)
{
    public static readonly SiteConditions Unknown = new(null, null);
}

/// <summary>Why an indicator is, or is not, among the trends shown.</summary>
public static class TrendOutcome
{
    public const string Shown = "shown";

    /// <summary>Says the same as a trend that is shown; listed there in <c>alsoSeenIn</c>.</summary>
    public const string Merged = "merged";

    /// <summary>Fewer years with a value than the rules ask for.</summary>
    public const string TooShort = "too_short";

    /// <summary>The Mann–Kendall test cannot tell it from chance.</summary>
    public const string NotSignificant = "not_significant";

    /// <summary>Statistically clear, but the change is too small to matter in practice.</summary>
    public const string BelowThreshold = "below_threshold";

    /// <summary>The slope and the difference of the period means point in different directions.</summary>
    public const string Inconsistent = "inconsistent";

    /// <summary>Clear, but more certain trends already fill the list.</summary>
    public const string OverLimit = "over_limit";
}

/// <summary>One indicator's series and the verdict on it.</summary>
public sealed record IndicatorAssessment
{
    public required IndicatorDefinition Indicator { get; init; }
    public required IndicatorRule Rule { get; init; }
    public required IReadOnlyList<int> Years { get; init; }
    public required IReadOnlyList<double> Values { get; init; }
    public required string Outcome { get; init; }
    public double? PValue { get; init; }
    public double? SlopePerYear { get; init; }
    public double? EarlyMean { get; init; }
    public double? RecentMean { get; init; }

    /// <summary>What the change means ("drier", ...); null unless the indicator qualified.</summary>
    public string? Change { get; init; }
}

/// <summary>A trend to show: the indicator that represents it and the ones merged into it.</summary>
public sealed record TrendFinding(IndicatorAssessment Shown, IReadOnlyList<IndicatorAssessment> AlsoSeenIn);

/// <summary>
/// The verdict on every indicator of one climate grid cell. It does not depend on the parcel, so it is what gets
/// cached; the advice is fitted to the parcel afterwards.
/// </summary>
public sealed record ClimateFindings(
    int FromYear, int ToYear, IReadOnlyList<IndicatorAssessment> Assessments, IReadOnlyList<TrendFinding> Trends)
{
    public bool HasEnoughYears => Assessments.Any(a => a.Outcome != TrendOutcome.TooShort);
}

/// <summary>
/// Looks for clear long-term changes in daily weather and attaches long-term options to them. Pure logic, no HTTP.
/// <para>It is deliberately hard to please, because showing a chance pattern as a "trend" would mislead a farmer:
/// a trend is shown only when the series is long enough, the Mann–Kendall test rules out chance, the slope agrees
/// with the difference between the first and the last years, and that difference is big enough to matter
/// (thresholds in <see cref="ClimateTrendRules"/>). Indicators that describe the same thing are shown once.
/// Nothing here extrapolates: the output is means of past years.</para>
/// </summary>
public static class ClimateTrendAnalyzer
{
    public const string StatusOk = "ok";
    public const string StatusNoClearTrends = "no_clear_trends";
    public const string StatusNoData = "no_data";

    public const string Up = "up";
    public const string Down = "down";

    public const string SoilLight = "light";
    public const string SoilOther = "other";

    /// <summary>The climate grid is about 50 km wide: the numbers describe the area, not this one field.</summary>
    public const string NoteRegionalGrid = "regional_climate_grid";

    /// <summary>Frost is counted from air temperature 2 m above ground; frost at the ground comes more often.</summary>
    public const string NoteAirFrost = "frost_measured_in_air";

    /// <summary>
    /// The water balance changed, but neither rain indicator did: the change comes from evaporation, which is
    /// estimated from temperature. Warmer weather alone must not read as "less rain".
    /// </summary>
    public const string NoteEvaporationFromTemperature = "evaporation_estimated_from_temperature";

    public const string SourceName = "NASA POWER (MERRA-2)";
    public const string SourceKindEstimated = "estimated";
    public const int GridKm = 50;

    private const string FrostGroup = "frost";
    private const string LastSpringFrostId = "last_spring_frost";
    private const string WaterBalanceId = "water_balance";

    public static IReadOnlyDictionary<DateOnly, WeatherDay> ToDays(NasaPowerDailyData data)
    {
        IReadOnlyDictionary<DateOnly, double> Series(string name) =>
            data.Parameters.TryGetValue(name, out var s) ? s : new Dictionary<DateOnly, double>();

        var (tMin, tMax, tMean, rain) = (Series("T2M_MIN"), Series("T2M_MAX"), Series("T2M"), Series("PRECTOTCORR"));
        double? At(IReadOnlyDictionary<DateOnly, double> s, DateOnly d) => s.TryGetValue(d, out var v) ? v : null;

        return tMin.Keys.Concat(tMax.Keys).Concat(tMean.Keys).Concat(rain.Keys).Distinct()
            .ToDictionary(d => d, d => new WeatherDay(At(tMin, d), At(tMax, d), At(tMean, d), At(rain, d)));
    }

    /// <summary>Judges every indicator of the rules on the years <paramref name="fromYear"/>–<paramref name="toYear"/>.</summary>
    public static ClimateFindings Find(
        IReadOnlyDictionary<DateOnly, WeatherDay> days, double latitude, int fromYear, int toYear, ClimateTrendRules rules)
    {
        var years = Enumerable.Range(fromYear, Math.Max(0, toYear - fromYear + 1))
            .Select(y => new YearWeather(y, latitude, days))
            .ToList();
        var definitions = YearlyIndicators.All.ToDictionary(i => i.Id);

        var assessments = rules.Indicators
            .Select(rule => Assess(definitions[rule.Id], rule, years, rules))
            .ToList();

        // Indicators that say the same thing (same group, same meaning) become one trend: the first in the
        // order of the rules is shown, the others are only named with it.
        var trends = new List<(IndicatorAssessment Shown, List<IndicatorAssessment> Also)>();
        for (var i = 0; i < assessments.Count; i++)
        {
            var a = assessments[i];
            if (a.Outcome != TrendOutcome.Shown)
                continue;

            var same = trends.FindIndex(t => t.Shown.Rule.Group == a.Rule.Group && t.Shown.Change == a.Change);
            if (same < 0)
            {
                trends.Add((a, []));
                continue;
            }

            assessments[i] = a with { Outcome = TrendOutcome.Merged };
            trends[same].Also.Add(assessments[i]);
        }

        var ordered = trends.OrderBy(t => t.Shown.PValue).ToList();
        foreach (var dropped in ordered.Skip(rules.MaxTrends))
        {
            foreach (var a in dropped.Also.Prepend(dropped.Shown))
                assessments[assessments.FindIndex(x => x.Indicator.Id == a.Indicator.Id)] = a with { Outcome = TrendOutcome.OverLimit };
        }

        var shown = ordered.Take(rules.MaxTrends)
            .Select(t => new TrendFinding(t.Shown, t.Also))
            .ToList();
        return new ClimateFindings(fromYear, toYear, assessments, shown);
    }

    private static IndicatorAssessment Assess(
        IndicatorDefinition indicator, IndicatorRule rule, List<YearWeather> years, ClimateTrendRules rules)
    {
        var series = years
            .Select(y => (y.Year, Value: indicator.Value(y)))
            .Where(p => p.Value is not null)
            .Select(p => (p.Year, Value: p.Value!.Value))
            .ToList();
        var seriesYears = series.Select(p => p.Year).ToList();
        var values = series.Select(p => p.Value).ToList();

        var assessment = new IndicatorAssessment
        {
            Indicator = indicator,
            Rule = rule,
            Years = seriesYears,
            Values = values,
            Outcome = TrendOutcome.TooShort,
        };
        if (series.Count < rules.MinYears || TrendStatistics.Analyze(seriesYears, values) is not { } trend)
            return assessment;

        var early = values.Take(rules.ComparedYears).Average();
        var recent = values.TakeLast(rules.ComparedYears).Average();
        var difference = recent - early;
        assessment = assessment with
        {
            PValue = trend.PValue,
            SlopePerYear = trend.SlopePerYear,
            EarlyMean = early,
            RecentMean = recent,
        };

        if (trend.PValue >= rules.MaxPValue)
            return assessment with { Outcome = TrendOutcome.NotSignificant };
        if (difference == 0 || Math.Sign(difference) != Math.Sign(trend.SlopePerYear))
            return assessment with { Outcome = TrendOutcome.Inconsistent };

        var threshold = rule.MinChange ?? rule.MinChangePercent!.Value / 100 * Math.Abs(early);
        if (Math.Abs(difference) < threshold)
            return assessment with { Outcome = TrendOutcome.BelowThreshold };

        return assessment with
        {
            Outcome = TrendOutcome.Shown,
            Change = difference > 0 ? rule.WhenUp : rule.WhenDown,
        };
    }

    /// <summary>Whether the parcel has light soil by the rules; null when neither texture nor complex is known.</summary>
    public static bool? IsLightSoil(string? topTextureCode, string? complexCode, ClimateTrendRules rules)
    {
        if (topTextureCode is null && complexCode is null)
            return null;

        return (topTextureCode is not null && rules.LightSoil.TextureCodes.Contains(topTextureCode))
               || (complexCode is not null && rules.LightSoil.Complexes.Contains(complexCode));
    }

    /// <summary>The answer for one parcel: the findings of its grid cell with advice fitted to the parcel.</summary>
    public static ClimateTrendsResponse Build(
        string? parcelId, double lat, double lon, ClimateFindings findings, SiteConditions site, ClimateTrendRules rules)
    {
        var trends = findings.Trends.Select(t => ToResponse(t, site, rules)).ToList();
        var status = !findings.HasEnoughYears ? StatusNoData
            : trends.Count == 0 ? StatusNoClearTrends
            : StatusOk;

        var notes = new List<string>();
        if (status != StatusNoData)
            notes.Add(NoteRegionalGrid);
        if (findings.Trends.Any(t => t.Shown.Rule.Group == FrostGroup))
            notes.Add(NoteAirFrost);
        // The rules list the rain indicators before the balance, so the balance is shown only when they did not qualify.
        if (findings.Trends.Any(t => t.Shown.Indicator.Id == WaterBalanceId))
            notes.Add(NoteEvaporationFromTemperature);

        return new ClimateTrendsResponse
        {
            ParcelId = parcelId,
            Lat = Math.Round(lat, 5),
            Lon = Math.Round(lon, 5),
            Status = status,
            FromYear = findings.FromYear,
            ToYear = findings.ToYear,
            GridKm = GridKm,
            Source = SourceName,
            SourceKind = SourceKindEstimated,
            NoteCodes = notes,
            Site = new ClimateTrendSite(
                site.LightSoil switch { true => SoilLight, false => SoilOther, null => null },
                site.SlopePct is { } slope ? Math.Round(slope, 1) : null),
            Trends = trends,
            Considered = findings.Assessments
                .Select(a => new ClimateIndicatorCheck(
                    a.Indicator.Id,
                    a.Outcome,
                    a.PValue is { } p ? Math.Round(p, 4) : null,
                    a.EarlyMean is { } early ? Math.Round(early, a.Indicator.Decimals) : null,
                    a.RecentMean is { } recent ? Math.Round(recent, a.Indicator.Decimals) : null))
                .ToList(),
        };
    }

    private static ClimateTrendResponse ToResponse(TrendFinding finding, SiteConditions site, ClimateTrendRules rules)
    {
        var a = finding.Shown;
        var decimals = a.Indicator.Decimals;
        var compared = rules.ComparedYears;

        return new ClimateTrendResponse
        {
            Id = a.Indicator.Id,
            Change = a.Change!,
            Direction = a.RecentMean > a.EarlyMean ? Up : Down,
            Unit = a.Indicator.Unit,
            EarlyMean = Math.Round(a.EarlyMean!.Value, decimals),
            RecentMean = Math.Round(a.RecentMean!.Value, decimals),
            EarlyFrom = a.Years[0],
            EarlyTo = a.Years[compared - 1],
            RecentFrom = a.Years[^compared],
            RecentTo = a.Years[^1],
            PValue = Math.Round(a.PValue!.Value, 4),
            AlsoSeenIn = finding.AlsoSeenIn.Select(x => x.Indicator.Id).ToList(),
            AdviceCodes = Advice(finding, site, rules),
            Years = a.Years,
            Values = a.Values.Select(v => Math.Round(v, decimals)).ToList(),
        };
    }

    /// <summary>
    /// General advice always; advice for light soil or a slope only when the parcel is known to have it, never
    /// on a guess.
    /// </summary>
    private static List<string> Advice(TrendFinding finding, SiteConditions site, ClimateTrendRules rules)
    {
        var codes = new List<string>();
        foreach (var rule in rules.Advice.Where(r => r.Change == finding.Shown.Change))
        {
            codes.AddRange(rule.Codes);

            if (site.LightSoil == true)
                codes.AddRange(rule.OnLightSoil);

            if (rule.SlopeAtLeastPct is { } minSlope && site.SlopePct >= minSlope)
                codes.AddRange(rule.OnSlope);

            var springFrostEarlier = finding.AlsoSeenIn.Prepend(finding.Shown).Any(a => a.Indicator.Id == LastSpringFrostId);
            if (!springFrostEarlier)
                codes.AddRange(rule.UnlessEarlierSpringFrost);
        }

        return codes.Distinct().ToList();
    }
}
