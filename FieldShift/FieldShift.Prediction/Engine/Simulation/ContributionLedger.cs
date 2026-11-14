using System.Collections.Immutable;
using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Simulation;

/// <summary>A change to a state variable and the season and crop that caused it.</summary>
public sealed record Contribution(int SeasonIndex, CropId Crop, double Delta);

/// <summary>
/// Per-variable record of who changed what, kept alongside the <see cref="SoilState"/> so responses can say
/// "this pressure is high because of seasons X and Y". Persistent: a search branch shares its prefix.
/// Season indices of history seasons are negative (the season before the plan is −1, and so on).
/// </summary>
public sealed class ContributionLedger
{
    private const double Negligible = 1e-12;

    private readonly ImmutableDictionary<StateVarId, ImmutableList<Contribution>> _entries;

    private ContributionLedger(ImmutableDictionary<StateVarId, ImmutableList<Contribution>> entries) =>
        _entries = entries;

    public static ContributionLedger Empty { get; } = new(ImmutableDictionary<StateVarId, ImmutableList<Contribution>>.Empty);

    public IReadOnlyList<Contribution> For(StateVarId variable) =>
        _entries.TryGetValue(variable, out var list) ? list : [];

    public ContributionLedger Add(StateVarId variable, Contribution contribution)
    {
        if (Math.Abs(contribution.Delta) < Negligible) return this;
        var list = _entries.TryGetValue(variable, out var existing) ? existing : [];
        return new ContributionLedger(_entries.SetItem(variable, list.Add(contribution)));
    }

    /// <summary>Multiplies every contribution to the variable (pressures decay, so do their causes).</summary>
    public ContributionLedger Scale(StateVarId variable, double factor)
    {
        if (!_entries.TryGetValue(variable, out var list)) return this;
        return new ContributionLedger(_entries.SetItem(variable,
            list.Select(c => c with { Delta = c.Delta * factor }).Where(c => Math.Abs(c.Delta) >= Negligible).ToImmutableList()));
    }

    public ContributionLedger Clear(StateVarId variable) =>
        _entries.ContainsKey(variable) ? new ContributionLedger(_entries.Remove(variable)) : this;

    /// <summary>
    /// The seasons that moved the variable most, largest absolute net contribution first. Contributions of the
    /// same season and crop are summed; ties go to the earlier season.
    /// </summary>
    public IReadOnlyList<Cause> Top(StateVarId variable, int count) =>
        For(variable)
            .GroupBy(c => (c.SeasonIndex, c.Crop))
            .Select(g => (g.Key.SeasonIndex, g.Key.Crop, Net: g.Sum(c => c.Delta)))
            .Where(x => Math.Abs(x.Net) >= Negligible)
            .OrderByDescending(x => Math.Abs(x.Net))
            .ThenBy(x => x.SeasonIndex)
            .ThenBy(x => x.Crop.Value, StringComparer.Ordinal)
            .Take(count)
            .Select(x => new Cause(x.SeasonIndex, x.Crop))
            .ToList();
}
