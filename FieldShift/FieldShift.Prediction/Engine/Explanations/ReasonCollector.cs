using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Explanations;

/// <summary>
/// Reasons of one kind that happened in one season, merged: the same code on the same variable counts once,
/// with its deltas added up.
/// </summary>
public sealed record ReasonGroup
{
    public required int SeasonIndex { get; init; }
    public required ReasonKind Kind { get; init; }
    public required string Code { get; init; }
    public CropId? Crop { get; init; }
    public StateVarId? Var { get; init; }

    /// <summary>How many reasons were merged into this one.</summary>
    public required int Count { get; init; }

    public required double TotalDelta { get; init; }

    /// <summary>The first reason's value and message (merged reasons share a code, so they read alike).</summary>
    public double? Value { get; init; }
    public string? Message { get; init; }
    public string? Source { get; init; }

    /// <summary>The distinct earlier seasons behind this reason, most recent first.</summary>
    public IReadOnlyList<Cause> CausedBy { get; init; } = [];
}

/// <summary>Merges a plan's reasons per season and ranks them by size, for "why this plan" explanations.</summary>
public static class ReasonCollector
{
    /// <summary>
    /// Merges reasons with the same season, code, crop and variable, adds up their deltas and sorts the result by
    /// |delta| (largest first), then season, then code, so the order is deterministic.
    /// </summary>
    public static IReadOnlyList<ReasonGroup> Aggregate(IEnumerable<Reason> reasons) =>
        reasons
            .GroupBy(r => (r.SeasonIndex, r.Code, Crop: r.Crop?.Value, Var: r.Var?.Value))
            .Select(g =>
            {
                var first = g.First();
                return new ReasonGroup
                {
                    SeasonIndex = first.SeasonIndex,
                    Kind = first.Kind,
                    Code = first.Code,
                    Crop = first.Crop,
                    Var = first.Var,
                    Count = g.Count(),
                    TotalDelta = g.Sum(r => r.Delta),
                    Value = first.Value,
                    Message = first.Message,
                    Source = first.Source,
                    CausedBy = g.SelectMany(r => r.CausedBy).Distinct()
                        .OrderByDescending(c => c.SeasonIndex).ThenBy(c => c.Crop.Value, StringComparer.Ordinal).ToList()
                };
            })
            .OrderByDescending(g => Math.Abs(g.TotalDelta))
            .ThenBy(g => g.SeasonIndex)
            .ThenBy(g => g.Code, StringComparer.Ordinal)
            .ThenBy(g => g.Crop?.Value, StringComparer.Ordinal)
            .ThenBy(g => g.Var?.Value, StringComparer.Ordinal)
            .ToList();

    /// <summary>The <paramref name="n"/> biggest merged reasons of one season of the plan.</summary>
    public static IReadOnlyList<ReasonGroup> TopReasons(PlanEvaluation plan, int seasonIndex, int n) =>
        Aggregate(plan.Reasons.Where(r => r.SeasonIndex == seasonIndex)).Take(n).ToList();

    /// <summary>The <paramref name="n"/> biggest merged reasons of the whole plan.</summary>
    public static IReadOnlyList<ReasonGroup> TopReasons(PlanEvaluation plan, int n) =>
        Aggregate(plan.Reasons).Take(n).ToList();
}
