namespace FieldShift.Prediction.Domain;

public enum InteractionTargetKind
{
    /// <summary>Scales the amount of a crop's (or action's) Add/Load effect on a variable.</summary>
    Effect,

    /// <summary>Scales the loss (1 - curve) of a crop's response to a variable.</summary>
    Response
}

public sealed record InteractionTrigger
{
    public required StateVarId Var { get; init; }

    /// <summary>Maps the variable's value at the start of the season to a 0..1 trigger strength.</summary>
    public required Curve Curve { get; init; }
}

public sealed record InteractionTarget
{
    public required InteractionTargetKind Kind { get; init; }
    public required StateVarId Var { get; init; }

    /// <summary>Effect targets only: Add or Load. Null means both.</summary>
    public EffectOp? Op { get; init; }
}

/// <summary>
/// "When variable A is high, the effect on / response to variable B is stronger (or weaker)."
/// The factor applied is 1 + (Multiplier - 1) x trigger, so it ramps in smoothly with the trigger curve.
/// </summary>
public sealed record StateInteraction : Sourced
{
    public required string Id { get; init; }
    public required InteractionTrigger When { get; init; }
    public required InteractionTarget Target { get; init; }
    public required double Multiplier { get; init; }

    /// <summary>Only crops matching this selector are affected (the effect's owner or the responding crop).</summary>
    public CropSelector? Crops { get; init; }
}
