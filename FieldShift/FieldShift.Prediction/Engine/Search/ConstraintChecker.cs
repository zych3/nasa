using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Features;

namespace FieldShift.Prediction.Engine.Search;

/// <summary>One season of the real or planned sequence: the crop and the year it is harvested.</summary>
public readonly record struct SeqEntry(Crop Crop, int Year);

public enum ViolationKind
{
    ExcludedCrop,
    Timing,
    MinReturnYears,
    MaxConsecutiveYears,
    SurvivalFloor,
    GroupShare
}

/// <summary>
/// A broken hard rule. A cheap struct on purpose: the search hits violations constantly and only the plans
/// that are finally shown need the text (see <see cref="ConstraintChecker.ToReason"/>).
/// </summary>
public readonly record struct ConstraintViolation(
    ViolationKind Kind, CropId Crop, int Year, int Other = 0, double Value = 0, string? Group = null);

/// <summary>
/// Hard rules, checked as each season is appended to the sequence (history, then transition, then cycle repeated).
/// <list type="bullet">
/// <item>Timing: a winter crop needs the previous harvest + soil preparation to end before its sowing window ends.</item>
/// <item>MinReturnYears: the same crop may not return sooner than this, counted across history and the wrap-around.</item>
/// <item>MaxConsecutiveYears.</item>
/// <item>Farmer exclusions.</item>
/// </list>
/// A perennial repeated in consecutive years is one stand: timing and return interval apply to the stand, not to
/// each year; only MaxConsecutiveYears limits its length. Spring crops are always feasible.
/// </summary>
public static class ConstraintChecker
{
    /// <summary>Checks the last entry of <paramref name="seq"/> against everything before it.</summary>
    public static ConstraintViolation? CheckAppend(
        IReadOnlyList<SeqEntry> seq, EngineSettings settings, IReadOnlySet<CropId> excluded)
    {
        var cur = seq[^1];
        var crop = cur.Crop;

        if (excluded.Contains(crop.Id))
            return new ConstraintViolation(ViolationKind.ExcludedCrop, crop.Id, cur.Year);

        var prev = seq.Count >= 2 ? seq[^2] : (SeqEntry?)null;
        var continuingStand = crop.Type == CropType.Perennial && prev is { } p && p.Crop.Id == crop.Id && p.Year == cur.Year - 1;

        if (prev is { } before && !continuingStand && crop.Type == CropType.Winter && before.Year == cur.Year - 1)
        {
            var free = before.Crop.HarvestWindow.End + settings.Calendar.SoilPrepDays;
            if (free > crop.SowWindow.End)
                return new ConstraintViolation(ViolationKind.Timing, crop.Id, cur.Year, Other: free, Value: crop.SowWindow.End,
                    Group: before.Crop.Id.Value);
        }

        if (crop.HardRules.MaxConsecutiveYears is { } maxConsecutive)
        {
            var run = 1;
            for (var i = seq.Count - 2; i >= 0 && seq[i].Crop.Id == crop.Id && seq[i].Year == seq[i + 1].Year - 1; i--)
                run++;
            if (run > maxConsecutive)
                return new ConstraintViolation(ViolationKind.MaxConsecutiveYears, crop.Id, cur.Year, Other: maxConsecutive, Value: run);
        }

        if (crop.HardRules.MinReturnYears is { } minReturn && !continuingStand)
        {
            for (var i = seq.Count - 2; i >= 0; i--)
            {
                if (seq[i].Crop.Id != crop.Id) continue;

                var gap = cur.Year - seq[i].Year;
                if (gap < minReturn)
                    return new ConstraintViolation(ViolationKind.MinReturnYears, crop.Id, cur.Year, Other: minReturn, Value: gap);
                break;       // the nearest earlier occurrence is the binding one
            }
        }

        return null;
    }

    /// <summary>The recorded history as a sequence for the checks, oldest first; seasons with unknown crops are left out.</summary>
    public static IReadOnlyList<SeqEntry> HistoryEntries(Plot plot, CropKnowledgeBase kb) =>
        plot.History
            .Select((h, order) => (h, order))
            .Where(x => kb.Crops.ContainsKey(x.h.Crop))
            .OrderBy(x => x.h.HarvestYear).ThenBy(x => x.order)
            .Select(x => new SeqEntry(kb.GetCrop(x.h.Crop), x.h.HarvestYear))
            .ToList();

    /// <summary>Largest number of cycle seasons a group may occupy: floor(maxShare · L).</summary>
    public static int GroupLimit(double maxShare, int cycleLength) => (int)Math.Floor(maxShare * cycleLength + 1e-9);

    /// <summary>Re-checks a whole plan from scratch: sequence rules over the unrolled plan, then group shares on the cycle.</summary>
    public static IReadOnlyList<Reason> Verify(
        RotationPlan plan, IReadOnlyList<SeqEntry> history, CropKnowledgeBase kb, EngineSettings settings,
        IReadOnlySet<CropId> excluded)
    {
        var reasons = new List<Reason>();
        var seq = history.ToList();
        var index = 0;

        foreach (var (year, season, _) in plan.Unroll(settings.Search.UnrollCycles))
        {
            seq.Add(new SeqEntry(kb.GetCrop(season.MainCrop), year));
            if (CheckAppend(seq, settings, excluded) is { } v)
                reasons.Add(ToReason(v, index));
            index++;
        }

        foreach (var share in settings.Constraints.GroupShares)
        {
            var count = plan.Cycle.Count(s => share.Selector.Matches(kb.GetCrop(s.MainCrop)));
            if (count > GroupLimit(share.MaxShare, plan.CycleLength))
                reasons.Add(ToReason(new ConstraintViolation(ViolationKind.GroupShare, plan.Cycle[0].MainCrop, plan.FirstHarvestYear,
                    Other: count, Value: share.MaxShare, Group: share.Selector.ToString()), plan.Transition.Count));
        }

        return reasons;
    }

    public static Reason ToReason(ConstraintViolation v, int seasonIndex)
    {
        var (code, message) = v.Kind switch
        {
            ViolationKind.ExcludedCrop =>
                ("hardRule.excludedCrop", Fmt.Inv($"{v.Crop} was excluded by the farmer.")),
            ViolationKind.Timing =>
                ("hardRule.timing", Fmt.Inv($"{v.Crop} must be sown by day {v.Value:0}, but the previous crop ({v.Group}) ") +
                                    Fmt.Inv($"and soil preparation only finish on day {v.Other}.")),
            ViolationKind.MinReturnYears =>
                ("hardRule.minReturnYears", Fmt.Inv($"{v.Crop} returns after {v.Value:0} year(s); it needs at least {v.Other}.")),
            ViolationKind.MaxConsecutiveYears =>
                ("hardRule.maxConsecutiveYears", Fmt.Inv($"{v.Crop} would be grown {v.Value:0} years in a row; the limit is {v.Other}.")),
            ViolationKind.SurvivalFloor =>
                ("hardRule.survivalFloor", Fmt.Inv($"Survival in the worst years is {v.Value:F2}, below the minimum {v.Other / 1000.0:F2}.")),
            ViolationKind.GroupShare =>
                ("hardRule.groupShare", Fmt.Inv($"{v.Other} of the cycle's seasons are {v.Group}, more than the allowed share {v.Value:P0}.")),
            _ => throw new ArgumentOutOfRangeException(nameof(v))
        };

        return new Reason
        {
            SeasonIndex = seasonIndex,
            Kind = ReasonKind.HardRuleViolation,
            Code = code,
            Crop = v.Crop,
            Value = v.Value,
            Message = message
        };
    }

    /// <summary>A survival-floor violation for a season whose CVaR is below the floor (floor passed in thousandths).</summary>
    public static ConstraintViolation SurvivalViolation(CropId crop, int year, double cvar, double floor) =>
        new(ViolationKind.SurvivalFloor, crop, year, Other: (int)Math.Round(floor * 1000), Value: cvar);

}
