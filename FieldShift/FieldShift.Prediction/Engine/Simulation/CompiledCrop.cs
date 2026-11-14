using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Validation;

namespace FieldShift.Prediction.Engine.Simulation;

/// <summary>An effect with everything the simulator needs resolved: state slot, parsed condition, scaling flag.</summary>
public sealed record CompiledEffect(
    Effect Effect, int Slot, StateVariable Variable, EffectOp Op, double Amount, bool ScalesWithNRate, ConditionKind When);

/// <summary>A response with its state slot resolved and its reason code built.</summary>
/// <param name="IsPressure">The response reads a pressure variable (what the Pathogen objective looks at).</param>
public sealed record CompiledResponse(
    Response Response, int Slot, string Code, bool IsPressure);

public sealed class CompiledAction
{
    public required ManagementActionDefinition Action { get; init; }
    public required CompiledEffect[] Effects { get; init; }
    public required ConditionKind? Requirement { get; init; }
}

/// <summary>
/// A crop prepared for fast simulation: resolved slots and parsed conditions, plus the crop-to-crop overrides
/// that apply after each possible previous crop. Built once per environment.
/// </summary>
public sealed class CompiledCrop
{
    public required Crop Crop { get; init; }
    public required CompiledEffect[] Effects { get; init; }
    public required CompiledResponse[] Responses { get; init; }

    /// <summary>Overrides that apply to this crop, keyed by the previous main crop. Absent key: none apply.</summary>
    public required IReadOnlyDictionary<CropId, InteractionOverride[]> OverridesAfter { get; init; }

    public static CompiledEffect[] CompileEffects(IReadOnlyList<Effect> effects, StateVariableRegistry registry) =>
        effects.Select(e =>
        {
            var slot = registry.IndexOf(e.Var);
            return new CompiledEffect(e, slot, registry.Ordered[slot], e.Op, e.Amount,
                e.ScaleBy == ConditionEvaluator.ScaleByNRate, ConditionEvaluator.Parse(e.When));
        }).ToArray();

    public static CompiledCrop Compile(Crop crop, CropKnowledgeBase kb)
    {
        var registry = kb.StateVariables;
        var overrides = new Dictionary<CropId, InteractionOverride[]>();
        foreach (var previous in kb.Crops.Values)
        {
            var applicable = kb.InteractionsFor(previous, crop).ToArray();
            if (applicable.Length > 0)
                overrides[previous.Id] = applicable;
        }

        return new CompiledCrop
        {
            Crop = crop,
            Effects = CompileEffects(crop.Effects, registry),
            Responses = crop.Responses.Select(r =>
            {
                var slot = registry.IndexOf(r.Var);
                var code = r.Target switch
                {
                    ResponseTarget.Survival => Fmt.Inv($"response.{r.Var}.survival"),
                    ResponseTarget.Yield => Fmt.Inv($"response.{r.Var}"),
                    _ => Fmt.Inv($"response.{r.Var}.penalty")
                };
                return new CompiledResponse(r, slot, code, registry.Ordered[slot].Kind == StateVariableKind.Pressure);
            }).ToArray(),
            OverridesAfter = overrides
        };
    }

    public static CompiledAction CompileAction(ManagementActionDefinition action, StateVariableRegistry registry) => new()
    {
        Action = action,
        Effects = CompileEffects(action.Effects, registry),
        Requirement = action.RequiresFarmerInput is null ? null : ConditionEvaluator.Parse(action.RequiresFarmerInput)
    };
}
