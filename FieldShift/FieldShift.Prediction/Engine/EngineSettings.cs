using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine;

/// <summary>Every tunable number of the engine. Loaded from engineSettings.json; no defaults live in code.</summary>
public sealed record EngineSettings
{
    public required CalendarSettings Calendar { get; init; }
    public required WinterSettings Winter { get; init; }
    public required SurvivalSettings Survival { get; init; }
    public required IReadOnlyList<TransformSettings> Transforms { get; init; }
    public required ObjectiveSettings Objectives { get; init; }
    public required ConstraintSettings Constraints { get; init; }
    public required SearchSettings Search { get; init; }
    public required PedotransferSettings Pedotransfer { get; init; }
    public required PhBufferSettings PhBuffer { get; init; }
    public required SoilSettings Soil { get; init; }
    public required ExplainSettings Explain { get; init; }
    public required ReportSettings Report { get; init; }
}

public sealed record ExplainSettings
{
    /// <summary>How many past seasons a "caused by" list names for one state variable.</summary>
    public required int MaxCauses { get; init; }
}

public sealed record SoilSettings
{
    /// <summary>Used for the humus stock when SoilGrids gives no bulk density.</summary>
    public required double DefaultBulkDensityGcm3 { get; init; }

    /// <summary>Depth of the layer the SoilGrids values describe (0–30 cm), for stocks per hectare.</summary>
    public required double TopsoilDepthM { get; init; }
}

public sealed record CalendarSettings
{
    public required int SoilPrepDays { get; init; }
    public required int CatchCropMinGrowthDays { get; init; }

    /// <summary>A catch crop cannot be counted on past this day of the year (frost), whatever its own window says.</summary>
    public required int CatchCropLatestEndDoy { get; init; }
}

public sealed record WinterSettings
{
    public required double SnowProtectionDepthCm { get; init; }
}

public enum FactorAggregation
{
    Min,
    GeometricMean
}

public sealed record SurvivalSettings
{
    public required FactorAggregation Aggregator { get; init; }
    public required double CvarFraction { get; init; }
    public required Curve WaterStressToScore { get; init; }

    /// <summary>Flowering window as fractions of the season, used when a crop has no stage lengths.</summary>
    public required NumericInterval HeatDaysFallbackWindowFraction { get; init; }
}

/// <summary>Cross-variable update applied at season end, e.g. acidificationCaO → ph.</summary>
public sealed record TransformSettings
{
    public required StateVarId From { get; init; }
    public required StateVarId To { get; init; }

    /// <summary>Expression that may reference plot features, e.g. "-1/plot.phBufferCaOPerUnit".</summary>
    public required string Factor { get; init; }

    public bool ResetFrom { get; init; }
}

public sealed record ObjectiveSettings
{
    public required Curve HumusPerYearToScore { get; init; }
    public required Curve PathogenPressureToScore { get; init; }
    public required Curve CompactionToScore { get; init; }

    /// <summary>Width of one root-depth class in metres; a crop is in class floor(rootDepth / width).</summary>
    public required double RootDepthClassM { get; init; }

    /// <summary>Number of distinct root-depth classes in a cycle that earns the full diversity score.</summary>
    public required int RootDepthClassesForFullScore { get; init; }
}

public sealed record GroupShare
{
    public required CropSelector Selector { get; init; }
    public required double MaxShare { get; init; }
}

public sealed record ConstraintSettings
{
    public required IReadOnlyList<GroupShare> GroupShares { get; init; }
}

public sealed record SearchSettings
{
    public required int MaxTransitionYears { get; init; }

    /// <summary>
    /// A one-season transition is a bridge into a cycle that cannot start right after the history. For each such
    /// start only this many bridge crops are tried: the legal ones with the best static survival.
    /// </summary>
    public required int BridgeCropsPerStart { get; init; }
    public required int UnrollCycles { get; init; }
    public required int TopKPerStrategy { get; init; }
    public required int AlternativesPerStrategy { get; init; }
    public required double MinAlternativeJaccardDistance { get; init; }
    public required int LocalSearchPasses { get; init; }
}

public sealed record PedotransferSettings
{
    public required string Method { get; init; }
}

public sealed record PhBufferSettings
{
    public required double BaseCaOPerUnit { get; init; }
    public required double PerClayPct { get; init; }
    public required double PerSocGkg { get; init; }
}

public sealed record ReportSettings
{
    /// <summary>Minimum agreement between the predecessor matrix and PredecessorRating (phase 7).</summary>
    public required double MinPredecessorAgreement { get; init; }
}
