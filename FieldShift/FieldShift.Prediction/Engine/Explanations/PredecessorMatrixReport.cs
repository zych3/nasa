using System.Text;
using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Simulation;

namespace FieldShift.Prediction.Engine.Explanations;

public sealed record PredecessorCell(CropId Previous, CropId Next, double Score);

public sealed record PredecessorDisagreement(
    CropId Next, CropId Previous, bool ExpectedBest, int Rank, int Of, double Score);

public sealed class PredecessorMatrixReport
{
    private PredecessorMatrixReport(
        IReadOnlyList<PredecessorCell> cells, IReadOnlyList<PredecessorDisagreement> disagreements, int ratedPairs)
    {
        Cells = cells;
        Disagreements = disagreements;
        RatedPairs = ratedPairs;
    }

    public IReadOnlyList<PredecessorCell> Cells { get; }
    public IReadOnlyList<PredecessorDisagreement> Disagreements { get; }

    public int RatedPairs { get; }

    public double Agreement => RatedPairs == 0 ? 1.0 : 1.0 - (double)Disagreements.Count / RatedPairs;

    public double ScoreOf(CropId previous, CropId next) =>
        Cells.Single(c => c.Previous == previous && c.Next == next).Score;

    public static PredecessorMatrixReport Build(SimEnvironment env)
    {
        var crops = env.Kb.Crops.Values.Where(c => c.IsMainCrop)
            .OrderBy(c => c.Id.Value, StringComparer.Ordinal).ToList();
        var cells = new List<PredecessorCell>();

        foreach (var previous in crops)
        {
            var afterPrevious = Run(env, env.InitialState(), previous.Id, 0, evaluate: false).Next;
            foreach (var next in crops)
            {
                var step = Run(env, afterPrevious, next.Id, 1, evaluate: true);
                var e = step.Evaluation;
                var score = Math.Clamp(e.SurvivalCvar20 * e.YieldFactor - step.Detail.Penalty, 0, 1);
                cells.Add(new PredecessorCell(previous.Id, next.Id, score));
            }
        }

        var disagreements = new List<PredecessorDisagreement>();
        var rated = 0;
        foreach (var next in crops.Where(c => c.PredecessorRating is not null))
        {
            var column = cells.Where(c => c.Next == next.Id).ToList();
            var of = column.Count;
            var pairs = next.PredecessorRating!.BestBefore.Select(p => (Previous: p, ExpectedBest: true))
                .Concat(next.PredecessorRating.WorstBefore.Select(p => (Previous: p, ExpectedBest: false)))
                .OrderBy(t => t.Previous.Value, StringComparer.Ordinal);

            foreach (var (previous, expectedBest) in pairs)
            {
                var cell = column.SingleOrDefault(c => c.Previous == previous);
                if (cell is null) continue;
                rated++;

                // Ties get the middle rank, so a crop that is no better than a pile of others does not count as "top".
                var better = column.Count(c => c.Score > cell.Score + 1e-12);
                var tied = column.Count(c => Math.Abs(c.Score - cell.Score) <= 1e-12);
                var midRank = better + (tied + 1) / 2.0;
                var position = of <= 1 ? 0.0 : (midRank - 1) / (of - 1);
                var agrees = expectedBest ? position <= 1.0 / 3 : position >= 2.0 / 3;
                if (!agrees)
                    disagreements.Add(new PredecessorDisagreement(
                        next.Id, previous, expectedBest, (int)Math.Round(midRank), of, cell.Score));
            }
        }

        return new PredecessorMatrixReport(cells, disagreements, rated);
    }

    public string ToCsv()
    {
        var sb = new StringBuilder("previous,next,score\n");
        foreach (var c in Cells)
            sb.Append(c.Previous.Value).Append(',').Append(c.Next.Value).Append(',')
              .Append(Fmt.Inv($"{c.Score:F4}")).Append('\n');
        return sb.ToString();
    }

    public IReadOnlyList<string> DisagreementLines() =>
        Disagreements.Select(d => Fmt.Inv(
            $"{d.Next} after {d.Previous}: rated {(d.ExpectedBest ? "best" : "worst")} before, but ranks {d.Rank} of {d.Of} (score {d.Score:F2})"))
            .ToList();

    private static StepResult Run(SimEnvironment env, SimState state, CropId crop, int index, bool evaluate) =>
        SeasonSimulator.Step(state, new SeasonContext
        {
            SeasonIndex = index,
            HarvestYear = 2000 + index,
            Season = new PlanSeason { MainCrop = crop },
            Env = env,
            EvaluateSurvival = evaluate
        });
}
