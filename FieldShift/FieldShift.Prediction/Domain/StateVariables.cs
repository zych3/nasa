using System.Text.Json;
using System.Text.Json.Serialization;

namespace FieldShift.Prediction.Domain;

public enum StateVariableKind
{
    Stock,
    Pool,
    Pressure,
    Event
}

public sealed record StateVariable : Sourced
{
    public required StateVarId Id { get; init; }
    public required StateVariableKind Kind { get; init; }
    public string? Unit { get; init; }
    public required StateDefault Default { get; init; }
    public double Min { get; init; } = double.NegativeInfinity;
    public double Max { get; init; } = double.PositiveInfinity;
 
    public double? DecayPerYear { get; init; }
 
    public string? Description { get; init; }
 
    public IReadOnlyList<CropId> HostCrops { get; init; } = [];
 
    public double Clamp(double value) => Math.Clamp(value, Min, Max);
}

[JsonConverter(typeof(StateDefaultJsonConverter))]
public readonly record struct StateDefault(double? Value, bool FromPlot)
{
    public const string FromPlotToken = "fromPlot";
    public static StateDefault Of(double value) => new(value, false);
    public static StateDefault Plot => new(null, true);
}

public sealed class StateDefaultJsonConverter : JsonConverter<StateDefault>
{
    public override StateDefault Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        reader.TokenType switch
        {
            JsonTokenType.Number => StateDefault.Of(reader.GetDouble()),
            JsonTokenType.String when reader.GetString() == StateDefault.FromPlotToken => StateDefault.Plot,
            _ => throw new JsonException($"State default must be a number or \"{StateDefault.FromPlotToken}\".")
        };
 
    public override void Write(Utf8JsonWriter writer, StateDefault value, JsonSerializerOptions options)
    {
        if (value.FromPlot) writer.WriteStringValue(StateDefault.FromPlotToken);
        else writer.WriteNumberValue(value.Value ?? 0);
    }
}

public sealed class StateVariableRegistry
{
    private readonly Dictionary<StateVarId, StateVariable> _byId;
 
    public StateVariableRegistry(IEnumerable<StateVariable> variables)
    {
        _byId = new Dictionary<StateVarId, StateVariable>();
        foreach (var v in variables)
        {
            if (!_byId.TryAdd(v.Id, v))
                throw new InvalidOperationException($"Duplicate state variable '{v.Id}'.");
        }
 
        var missing = StateVarId.Required.Where(id => !_byId.ContainsKey(id)).ToList();
        if (missing.Count > 0)
            throw new InvalidOperationException($"Missing required state variables: {string.Join(", ", missing)}.");

        Ordered = _byId.Values.OrderBy(v => v.Id.Value, StringComparer.Ordinal).ToArray();
        _index = Ordered.Select((v, i) => (v.Id, i)).ToDictionary(x => x.Id, x => x.i);
    }

    private readonly Dictionary<StateVarId, int> _index;

    public IReadOnlyList<StateVariable> Ordered { get; }

    public int Count => Ordered.Count;

    public int IndexOf(StateVarId id) =>
        _index.TryGetValue(id, out var i)
            ? i
            : throw new KeyNotFoundException($"State variable '{id}' is not registered in stateVars.json.");

    public IReadOnlyCollection<StateVariable> All => Ordered;
 
    public bool Contains(StateVarId id) => _byId.ContainsKey(id);
 
    public StateVariable this[StateVarId id] =>
        _byId.TryGetValue(id, out var v)
            ? v
            : throw new KeyNotFoundException($"State variable '{id}' is not registered in stateVars.json.");
 
    public IEnumerable<StateVariable> OfKind(StateVariableKind kind) => _byId.Values.Where(v => v.Kind == kind);
}