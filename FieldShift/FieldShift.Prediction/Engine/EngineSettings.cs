using FieldShift.Prediction.Domain;

namespace FieldShift.Prediction.Engine;

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

    public InteractionSettings Interactions { get; init; } = new();
}

public sealed record InteractionSettings
{
    /// <summary>Upper bound for the combined factor of all rules acting on one effect or response.</summary>
    public double MaxMultiplier { get; init; } = 3.0;
}

public sealed record ExplainSettings
{
    public required int MaxCauses { get; init; }
}

public sealed record SoilSettings
{
    public required double DefaultBulkDensityGcm3 { get; init; }

    public required double TopsoilDepthM { get; init; }
}

public sealed record CalendarSettings
{
    public required int SoilPrepDays { get; init; }
    public required int CatchCropMinGrowthDays { get; init; }

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

    public required NumericInterval HeatDaysFallbackWindowFraction { get; init; }

    /// <summary>
    /// Newer climate years count more: a year's weight is 0.5 ^ (years before the latest / half-life). Null means all
    /// years count the same. This is not a forecast, only less reliance on old weather.
    /// </summary>
    public double? RecencyHalfLifeYears { get; init; }
}

public sealed record TransformSettings
{
    public required StateVarId From { get; init; }
    public required StateVarId To { get; init; }

    public required string Factor { get; init; }

    public bool ResetFrom { get; init; }
}

public sealed record ObjectiveSettings
{
    public required Curve HumusPerYearToScore { get; init; }
    public required Curve PathogenPressureToScore { get; init; }
    public required Curve CompactionToScore { get; init; }

    public required double RootDepthClassM { get; init; }

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
    public required double MinPredecessorAgreement { get; init; }
}
