namespace FieldShift.Prediction.Domain;

 
public enum EffectOp
{
    Add,
    Load,
    Multiply,
    Set
}

public sealed record Effect : Sourced
{
    public required StateVarId Var { get; init; }
    public required EffectOp Op { get; init; }
    public required double Amount { get; init; }

    public string? ScaleBy { get; init; }
 
    public string? When { get; init; }
}

public enum ResponseTarget
{
    Survival,
    Yield,
    Penalty
}

public sealed record Response : Sourced
{
    public required StateVarId Var { get; init; }
    public required Curve Curve { get; init; }
    public required ResponseTarget Target { get; init; }
    public double Weight { get; init; } = 1.0;
}

public sealed record ToleranceRange
{
    public double? AbsMin { get; init; }
    public double? OptMin { get; init; }
    public double? OptMax { get; init; }
    public double? AbsMax { get; init; }
 
    public bool IsValid =>
        Ordered(AbsMin, OptMin) && Ordered(OptMin, OptMax) && Ordered(OptMax, AbsMax) && Ordered(AbsMin, AbsMax);
 
    public double Score(double x)
    {
        var lo = OptMin ?? AbsMin ?? double.NegativeInfinity;
        var hi = OptMax ?? AbsMax ?? double.PositiveInfinity;
 
        if (x >= lo && x <= hi) return 1;
 
        if (x < lo)
            return AbsMin is { } a && a < lo && x > a ? (x - a) / (lo - a) : 0;
 
        return AbsMax is { } b && b > hi && x < b ? (b - x) / (b - hi) : 0;
    }
 
    private static bool Ordered(double? a, double? b) => a is null || b is null || a <= b;
}