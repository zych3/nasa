namespace FieldShift.Prediction.Engine.Search;

/// <summary>
/// Keeps the plans nobody beats: no member is at least as good on every objective and strictly better on one.
/// Same rule as <c>ObjectiveScores.Dominates</c>, on plain arrays so it is fast enough for the search's inner loop.
/// Plans with identical scores do not dominate each other; both stay.
/// </summary>
public sealed class ParetoArchive
{
    private readonly List<PlanCandidate> _members = [];

    public IReadOnlyList<PlanCandidate> Members => _members;
    public int Count => _members.Count;

    /// <summary>True if no member dominates these scores, so a candidate with them would be kept.</summary>
    public bool Accepts(double[] vector)
    {
        foreach (var member in _members)
        {
            if (Dominates(member.Vector, vector))
                return false;
        }
        return true;
    }

    /// <returns>True if the candidate entered the archive (it was not dominated).</returns>
    public bool TryAdd(PlanCandidate candidate)
    {
        foreach (var member in _members)
        {
            if (Dominates(member.Vector, candidate.Vector))
                return false;
        }

        _members.RemoveAll(m => Dominates(candidate.Vector, m.Vector));
        _members.Add(candidate);
        return true;
    }

    /// <summary>True when <paramref name="a"/> is at least as good everywhere and strictly better somewhere.</summary>
    public static bool Dominates(double[] a, double[] b)
    {
        var strictlyBetter = false;
        for (var i = 0; i < a.Length; i++)
        {
            if (a[i] < b[i]) return false;
            if (a[i] > b[i]) strictlyBetter = true;
        }
        return strictlyBetter;
    }
}
