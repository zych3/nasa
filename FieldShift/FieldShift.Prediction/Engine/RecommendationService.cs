using FieldShift.Prediction.Domain;
using FieldShift.Prediction.Engine.Climate;
using FieldShift.Prediction.Engine.Features;
using FieldShift.Prediction.Engine.Planning;
using FieldShift.Prediction.Engine.Search;
using FieldShift.Prediction.Engine.Simulation;
using FieldShift.Prediction.Engine.Survival;
using FieldShift.Prediction.Engine.Validation;

namespace FieldShift.Prediction.Engine;

public sealed record RecommendationResult(
    IReadOnlyList<Recommendation> Recommendations,
    IReadOnlyList<PlanEvaluation> ParetoFront,
    IReadOnlyList<CropScreeningResult> Screening,
    IReadOnlyList<Reason> Warnings);

/// <summary>The engine's front door: plot + knowledge base + settings in, explained rotation plans out.</summary>
public static class RecommendationService
{
    /// <param name="strategies">Which strategies to answer; null means all of them in the knowledge base.</param>
    /// <param name="timeProvider">Only used to stamp the result; pass a fixed one to get byte-identical output.</param>
    public static RecommendationResult Recommend(
        Plot plot, CropKnowledgeBase kb, EngineSettings settings,
        IReadOnlyList<StrategyId>? strategies = null,
        CancellationToken ct = default,
        TimeProvider? timeProvider = null,
        SearchOptions? searchOptions = null)
    {
        var report = KnowledgeBaseValidator.Validate(kb, settings);
        if (!report.IsValid)
            throw new ArgumentException("The knowledge base or settings are invalid:" + Environment.NewLine + report);

        var chosen = ResolveStrategies(kb, strategies);
        var warnings = new List<Reason>();

        // Plot features, climate and screening: which crops are worth searching with at all.
        var built = FeatureBuilder.Build(plot, settings);
        warnings.AddRange(built.Reasons.Where(r => r.Code.EndsWith(".outOfRange", StringComparison.Ordinal)));

        var climate = new ClimateIndex(plot.Climate, plot.Location.Lat);
        var screening = CropScreener.Screen(kb, built.Features, climate, plot.Farmer, settings, chosen);
        warnings.AddRange(screening.Warnings);

        // The soil the plans start from.
        var provisional = new SimEnvironment(kb, built.Features, settings, plot.Farmer, screening.Survival);
        var seeded = HistorySeeder.Seed(plot, provisional);
        warnings.AddRange(seeded.Warnings);

        var history = ConstraintChecker.HistoryEntries(plot, kb);
        var firstYear = plot.History.Count > 0
            ? plot.History.Max(h => h.HarvestYear) + 1
            : climate.Years.Count > 0 ? climate.Years.Max() + 1 : 0;

        var mainCrops = screening.Candidates
            .Select(r => kb.GetCrop(r.Crop)).Where(c => c.IsMainCrop).ToList();
        var catchCrops = screening.Candidates
            .Select(r => kb.GetCrop(r.Crop)).Where(c => c.Type == CropType.Catch).ToList();

        if (mainCrops.Count == 0)
        {
            warnings.Add(Warning("search.noCandidates", "No crop survives screening on this plot, so no plan can be built."));
            return new RecommendationResult([], [], screening.Results, warnings);
        }

        var outcome = new RotationSearch(provisional, seeded.State, history, firstYear, mainCrops, chosen, searchOptions).Run(ct);

        var now = (timeProvider ?? TimeProvider.System).GetUtcNow();
        var recommendations = new List<Recommendation>();
        var excluded = plot.Farmer.ExcludedCrops.ToHashSet();

        foreach (var strategy in chosen)
        {
            ct.ThrowIfCancellationRequested();
            var picked = Pick(strategy, outcome, settings);
            if (picked.Count == 0)
            {
                warnings.Add(Warning(Fmt.Inv($"recommend.noPlan.{strategy.Id}"),
                    Fmt.Inv($"No plan meets the '{strategy.Id}' strategy's limits (cycle length {strategy.MinCycleYears}-{strategy.MaxCycleYears}, ") +
                    Fmt.Inv($"survival at least {strategy.SurvivalFloor:F2}).")));
                continue;
            }

            var optimizer = new CatchCropAndActionOptimizer(provisional, seeded.State, strategy, catchCrops);
            var weights = StrategySelector.Weights(strategy, Objectives.ObjectiveScorer.Scored);

            var evaluations = picked
                .Select(c => optimizer.Optimize(c.Plan).Plan)
                .Select(plan => Finalise(plan, seeded.State, provisional, history, kb, settings, excluded, strategy))
                .ToList();

            double Score(PlanEvaluation e) => StrategySelector.WeightedScore(weights,
                Objectives.ObjectiveScorer.Scored.Select(o => e.Scores[o]).ToArray());

            // A weighted strategy lists its plans by score; a knee strategy keeps its balance-based order.
            if (strategy.Mode == SelectionMode.WeightedSum)
                evaluations = evaluations.OrderByDescending(Score)
                    .ThenBy(e => PlanCandidate.BuildKey(e.Plan), StringComparer.Ordinal).ToList();

            recommendations.Add(new Recommendation
            {
                Strategy = strategy.Id,
                Best = evaluations[0],
                Alternatives = evaluations.Skip(1).ToList(),
                StrategyScore = Score(evaluations[0]),
                KnowledgeBaseVersion = kb.Version,
                GeneratedAtUtc = now
            });
        }

        var front = outcome.Front
            .Select(c => PlanEvaluator.Evaluate(c.Plan, seeded.State, provisional, collectReasons: false))
            .ToList();

        return new RecommendationResult(recommendations, front, screening.Results, warnings);
    }

    private static IReadOnlyList<PlanCandidate> Pick(Strategy strategy, SearchOutcome outcome, EngineSettings settings)
    {
        var topK = outcome.TopK.TryGetValue(strategy.Id, out var list) ? list : [];
        var ranked = StrategySelector.Rank(strategy, outcome.Front, topK, Objectives.ObjectiveScorer.Scored);
        return StrategySelector.PickBestAndAlternatives(ranked, settings.Search);
    }

    private static PlanEvaluation Finalise(
        RotationPlan plan, SimState start, SimEnvironment env, IReadOnlyList<SeqEntry> history,
        CropKnowledgeBase kb, EngineSettings settings, IReadOnlySet<CropId> excluded, Strategy strategy)
    {
        var evaluation = PlanEvaluator.Evaluate(plan, start, env);
        var violations = ConstraintChecker.Verify(plan, history, kb, settings, excluded).ToList();

        foreach (var s in evaluation.Seasons.Where(s => s.SurvivalCvar20 < strategy.SurvivalFloor - 1e-9))
            violations.Add(ConstraintChecker.ToReason(
                ConstraintChecker.SurvivalViolation(s.Crop, s.HarvestYear, s.SurvivalCvar20, strategy.SurvivalFloor), s.SeasonIndex));

        return evaluation with { Violations = violations };
    }

    private static IReadOnlyList<Strategy> ResolveStrategies(CropKnowledgeBase kb, IReadOnlyList<StrategyId>? requested)
    {
        if (requested is null)
            return kb.Strategies.Values.OrderBy(s => s.Id.Value, StringComparer.Ordinal).ToList();

        var unknown = requested.Where(id => !kb.Strategies.ContainsKey(id)).ToList();
        if (unknown.Count > 0)
            throw new ArgumentException(Fmt.Inv($"Unknown strategies: {string.Join(", ", unknown)}."), nameof(requested));

        return requested.Distinct().Select(id => kb.Strategies[id]).OrderBy(s => s.Id.Value, StringComparer.Ordinal).ToList();
    }

    private static Reason Warning(string code, string message) => new()
    {
        SeasonIndex = FeatureBuilder.PlotLevel,
        Kind = ReasonKind.Suitability,
        Code = code,
        Message = message
    };
}
