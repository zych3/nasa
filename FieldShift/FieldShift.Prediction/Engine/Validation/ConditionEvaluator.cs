using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine.Validation;

/// <summary>A parsed <see cref="Effect.When"/> condition. Parsing once keeps the simulator's inner loop free of string work.</summary>
public enum ConditionKind
{
    Always,
    ResidueIncorporate,
    ResidueRemove,
    ResidueMulch,
    LivestockOrManure,
    Irrigation
}

/// <summary>
/// Evaluates <see cref="Effect.When"/> conditions. Supported: residue.&lt;incorporate|remove|mulch&gt;,
/// farmer.hasLivestockOrManure, farmer.hasIrrigation. Also knows the supported <see cref="Effect.ScaleBy"/> keys.
/// </summary>
public static class ConditionEvaluator
{
    public const string ResidueNamespace = "residue.";
    public const string HasLivestockOrManure = "farmer.hasLivestockOrManure";
    public const string HasIrrigation = "farmer.hasIrrigation";
    public const string ScaleByNRate = "management.nRate";

    public static bool IsSupported(string condition)
    {
        if (condition.StartsWith(ResidueNamespace, StringComparison.Ordinal))
            return Enum.TryParse<ResidueHandling>(condition[ResidueNamespace.Length..], ignoreCase: true, out _);

        return condition is HasLivestockOrManure or HasIrrigation;
    }

    public static bool IsSupportedScaleBy(string key) => key == ScaleByNRate;

    /// <summary>Null (no condition) means <see cref="ConditionKind.Always"/>.</summary>
    /// <exception cref="ArgumentException">The condition is not supported.</exception>
    public static ConditionKind Parse(string? condition)
    {
        if (condition is null) return ConditionKind.Always;

        if (condition.StartsWith(ResidueNamespace, StringComparison.Ordinal)
            && Enum.TryParse<ResidueHandling>(condition[ResidueNamespace.Length..], ignoreCase: true, out var residue))
            return residue switch
            {
                ResidueHandling.Incorporate => ConditionKind.ResidueIncorporate,
                ResidueHandling.Remove => ConditionKind.ResidueRemove,
                _ => ConditionKind.ResidueMulch
            };

        return condition switch
        {
            HasLivestockOrManure => ConditionKind.LivestockOrManure,
            HasIrrigation => ConditionKind.Irrigation,
            _ => throw new ArgumentException(Fmt.Inv($"Unsupported condition '{condition}'."), nameof(condition))
        };
    }

    public static bool Evaluate(ConditionKind kind, ResidueHandling residue, FarmerInputs farmer) => kind switch
    {
        ConditionKind.Always => true,
        ConditionKind.ResidueIncorporate => residue == ResidueHandling.Incorporate,
        ConditionKind.ResidueRemove => residue == ResidueHandling.Remove,
        ConditionKind.ResidueMulch => residue == ResidueHandling.Mulch,
        ConditionKind.LivestockOrManure => farmer.HasLivestockOrManure,
        ConditionKind.Irrigation => farmer.HasIrrigation,
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    public static bool Evaluate(string condition, ResidueHandling residue, FarmerInputs farmer) =>
        Evaluate(Parse(condition), residue, farmer);
}
