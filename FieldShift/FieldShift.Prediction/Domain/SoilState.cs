namespace FieldShift.Prediction.Domain;

public sealed class SoilState
{
    private readonly StateVariableRegistry _registry;
    private readonly double[] _values;

    private SoilState(StateVariableRegistry registry, double[] values)
    {
        _registry = registry;
        _values = values;
    }

    public static SoilState Initial(StateVariableRegistry registry, Func<StateVarId, double> fromPlot)
    {
        var values = new double[registry.Count];
        for (var i = 0; i < values.Length; i++)
        {
            var v = registry.Ordered[i];
            values[i] = v.Clamp(v.Default.FromPlot ? fromPlot(v.Id) : v.Default.Value ?? 0);
        }
        return new SoilState(registry, values);
    }

    public static SoilState FromValues(StateVariableRegistry registry, ReadOnlySpan<double> values)
    {
        if (values.Length != registry.Count)
            throw new ArgumentException($"Expected {registry.Count} values but got {values.Length}.", nameof(values));

        var copy = new double[values.Length];
        for (var i = 0; i < copy.Length; i++)
            copy[i] = registry.Ordered[i].Clamp(values[i]);
        return new SoilState(registry, copy);
    }

    internal static SoilState FromOwnedValues(StateVariableRegistry registry, double[] values)
    {
        for (var i = 0; i < values.Length; i++)
            values[i] = registry.Ordered[i].Clamp(values[i]);
        return new SoilState(registry, values);
    }

    public double this[StateVarId id] =>
        _values[_registry.IndexOf(id)];

    public double this[int index] => _values[index];

    public IEnumerable<KeyValuePair<StateVarId, double>> Values
    {
        get
        {
            for (var i = 0; i < _values.Length; i++)
                yield return new KeyValuePair<StateVarId, double>(_registry.Ordered[i].Id, _values[i]);
        }
    }

    public double[] ToArray() => (double[])_values.Clone();

    public SoilState With(StateVariable variable, double value)
    {
        var copy = (double[])_values.Clone();
        copy[_registry.IndexOf(variable.Id)] = variable.Clamp(value);
        return new SoilState(_registry, copy);
    }

    public SoilState With(IEnumerable<(StateVariable Variable, double Value)> changes)
    {
        var copy = (double[])_values.Clone();
        foreach (var (variable, value) in changes)
            copy[_registry.IndexOf(variable.Id)] = variable.Clamp(value);
        return new SoilState(_registry, copy);
    }
}

public enum ReasonKind
{
    Suitability,
    StateResponse,
    StateEffect,
    InteractionOverride,
    Timing,
    HardRuleViolation,
    Decay,

    Objective
}

public sealed record Cause(int SeasonIndex, CropId Crop);

public sealed record Reason
{
    public required int SeasonIndex { get; init; }
    public required ReasonKind Kind { get; init; }

    public required string Code { get; init; }

    public CropId? Crop { get; init; }
    public StateVarId? Var { get; init; }

    public double? Value { get; init; }

    public double Delta { get; init; }

    public IReadOnlyList<Cause> CausedBy { get; init; } = [];
    public string? Source { get; init; }
    public string? Message { get; init; }
}
