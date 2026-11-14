namespace FieldShift.Prediction.Engine.Calendar;

/// <summary>FAO-56 growth stages.</summary>
public enum GrowthStage
{
    Initial,
    Development,
    Mid,
    Late
}

public sealed record SeasonDates
{
    public required int HarvestYear { get; init; }

    public required bool SownPreviousYear { get; init; }

    public required DateOnly Sow { get; init; }
    
    public required DateOnly ActiveStart { get; init; }

    public required DateOnly End { get; init; }
    public required DateOnly FloweringStart { get; init; }
    public required DateOnly FloweringEnd { get; init; }

    public IReadOnlyList<DateOnly> StageEnds { get; init; } = [];

    public bool HasStages => StageEnds.Count == 4;

    public GrowthStage? StageAt(DateOnly date)
    {
        if (!HasStages || date < ActiveStart || date > End) return null;
        for (var i = 0; i < 4; i++)
        {
            if (date <= StageEnds[i]) return (GrowthStage)i;
        }
        return GrowthStage.Late;
    }

    public DateOnly StageStart(GrowthStage stage) =>
        stage == GrowthStage.Initial ? ActiveStart : StageEnds[(int)stage - 1].AddDays(1);
}
