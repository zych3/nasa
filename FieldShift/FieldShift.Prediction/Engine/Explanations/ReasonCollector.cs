using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Explanations;

public sealed record ReasonGroup
{
    public required int SeasonIndex { get; init; }
    public required ReasonKind Kind { get; init; }
    public required string Code { get; init; }
    public CropId? Crop { get; init; }
    public StateVarId? Var { get; init; }

    public required int Count { get; init; }

    public required double TotalDelta { get; init; }

    public double? Value { get; init; }
    public string? Message { get; init; }
    public string? Source { get; init; }

    public IReadOnlyList<Cause> CausedBy { get; init; } = [];
}

public static class ReasonCollector
{
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

    public static IReadOnlyList<ReasonGroup> TopReasons(PlanEvaluation plan, int seasonIndex, int n) =>
        Aggregate(plan.Reasons.Where(r => r.SeasonIndex == seasonIndex)).Take(n).ToList();

    public static IReadOnlyList<ReasonGroup> TopReasons(PlanEvaluation plan, int n) =>
        Aggregate(plan.Reasons).Take(n).ToList();
}
