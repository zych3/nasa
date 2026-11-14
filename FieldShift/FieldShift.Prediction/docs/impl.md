# Task: Implement the crop-rotation recommendation engine

You are implementing the decision engine of a crop-rotation app for Polish farms. Given a plot (soil, 25 years of daily climate, optional farmer inputs and crop history) and a data-driven crop knowledge base, the engine must recommend crop rotations under several optimisation strategies (soil health, crop survival, balanced) and explain every recommendation.

Read this whole document before writing code. Work in the phases listed at the end, run the tests after each phase, and stop to summarise after each phase.

---

## 0. Context and non-negotiable principles

### Existing code
A domain model already exists in `CropRotation.Domain` (namespaces `CropRotation.Domain.Common`, `.KnowledgeBase`, `.Plots`, `.Simulation`, `.Planning`). **It has never been compiled.** First make it build with minimal fixes. Key types:

- `CropKnowledgeBase`: aggregate of `StateVariableRegistry`, `Crop`s, `ManagementActionDefinition`s, `InteractionOverride`s, `Strategy`s.
- `Crop`: `Suitability` (static tolerances via `ToleranceRange`), `WaterProfile` (FAO-56), `Responses` (reads of `SoilState` through a `Curve`), `Effects` (writes to `SoilState`), `HardRules`, `ManagementDefaults`.
- `StateVariable` kinds: `Stock`, `Pool`, `Pressure`, `Event`.
- `SoilState`: immutable, every registered variable always has a value, clamped to [Min, Max].
- `Plot`, `PlotFeatures`, `ClimateYear`/`DailyWeather`, `FarmerInputs`, `HistoricSeason`.
- `RotationPlan` (transition seasons + repeating cycle), `PlanSeason`, `SeasonEvaluation`, `ObjectiveScores` (with `Dominates`), `PlanEvaluation`, `Recommendation`, `Reason`.

Target .NET 9, C# 13, nullable enabled, implicit usings. Tests: xUnit (+ FluentAssertions if you like).

### Principles
1. **No crop-specific code.** The engine must never reference a crop id, family, tag or pathogen name in C#. Every agronomic fact comes from the knowledge base. Every tunable number (thresholds, normalisation curves, search limits) comes from `engineSettings.json`. Add an architecture test that fails if engine source files contain string literals matching crop ids from the fixture knowledge base or known prefixes such as `"pathogen:"`.
2. **Crop-to-crop interactions emerge from shared state.** Predecessor crop effects write `SoilState`, and following crops read it through `Responses`. `InteractionOverride` is only a residual correction.
3. **Explainability.** Every score contribution, state change, exclusion and constraint violation emits a `Reason` with a stable `Code`.
4. **Deterministic.** Same input, same output. Use stable ordering and break ties by crop id ordinal. Parallelism must not change results.
5. **Pure core.** The engine does no I/O except an optional loader. All services are stateless and are given their inputs explicitly.

### Allowed domain changes
You may make these changes to the domain model. Note each one in your phase summary:
- `PlanSeason.Residue` → `ResidueHandling?` (null = the crop's `Management.Residue` default).
- Add `CropScreeningResult`, `RecommendationResult`, `EngineSettings` and related types. Put engine-specific types in the Engine project unless they are clearly domain types.
- Fix compile errors.

Ask before making any other structural change to the domain model.

---

## 1. Project layout

Public entry point:

```csharp
RecommendationResult Recommend(Plot plot, CropKnowledgeBase kb, EngineSettings settings,
                               IReadOnlyList<StrategyId>? strategies = null,
                               CancellationToken ct = default);

// RecommendationResult:
//   IReadOnlyList<Recommendation> Recommendations   (one per strategy)
//   IReadOnlyList<PlanEvaluation> ParetoFront
//   IReadOnlyList<CropScreeningResult> Screening   (why each crop is in or out)
//   IReadOnlyList<Reason> Warnings                 (data gaps, unknown history crops, etc.)
```

---

## 2. Engine settings (`engineSettings.json`)

Create an `EngineSettings` record and a default JSON file. Every value below must live here, not in code:

```jsonc
{
  "calendar": { "soilPrepDays": 10, "catchCropMinGrowthDays": 45 },
  "winter": { "snowProtectionDepthCm": 5 },
  "survival": {
    "aggregator": "min",              // "min" | "geometricMean"
    "cvarFraction": 0.2,
    "waterStressToScore": [[0,1],[0.3,0.7],[0.6,0.2],[1,0]],
    "heatDaysFallbackWindowFraction": [0.45, 0.70]   // used when the crop has no stage lengths
  },
  "transforms": [
    // cross-variable updates applied at season end; factor may reference plot features
    { "from": "acidificationCaO", "to": "ph", "factor": "-1/plot.phBufferCaOPerUnit", "resetFrom": true }
  ],
  "objectives": {
    "humusPerYearToScore": [[-400,0],[0,0.6],[200,1]],
    "pathogenPressureToScore": [[0,1],[0.5,0.4],[1,0]],
    "compactionToScore": [[-0.5,1],[0,0.7],[0.5,0]]
  },
  "constraints": {
    "groupShares": [ { "selector": "tag:cereal", "maxShare": 0.67 } ]   // selectors use the existing CropSelector syntax
  },
  "search": {
    "maxTransitionYears": 1,
    "unrollCycles": 2,
    "topKPerStrategy": 200,
    "alternativesPerStrategy": 3,
    "minAlternativeJaccardDistance": 0.3,
    "localSearchPasses": 2
  },
  "pedotransfer": { "method": "saxtonRawls2006" },
  "phBuffer": { "baseCaOPerUnit": 1000, "perClayPct": 80, "perSocGkg": 40 }   // documented approximation, tunable
}
```

The `"tag:cereal"` example is data, not code. That is fine.

---

## 3. Phase-by-phase specification

### Phase 1: Build, load, validate

- Make `CropRotation.Domain` compile.
- `KnowledgeBaseLoader`: reads `stateVars.json`, `crops/*.json` (each file contains one crop or an array of crops), `actions.json`, `interactions.json`, `strategies.json`, `engineSettings.json` using `DomainJson.Options`.
- `KnowledgeBaseValidator` returns all errors, not only the first. It must reject:
    - Effect or Response vars that are not registered.
    - `Load` on a non-pressure variable, or `Set` on a non-event variable (Set is a warning only for stocks).
    - Invalid `ToleranceRange` or `DoyWindow`.
    - `Kc`/`StageLengthsDays` with the wrong length.
    - Pressures without `DecayPerYear`, or with a value outside [0, 1].
    - Unknown crop ids in `PredecessorRating` or `HistoricSeason`.
    - Selectors that match no crop.
    - `Source` ids that don't exist in the crop's `Sources`.
    - Strategy weights referencing unknown objectives.

  It also emits warnings: a crop with no `ph` response, a crop with no pressure loads, and confidence statistics per crop.
- Tests: valid fixture passes; one test per rejection rule.

### Phase 2: Plot features and climate

- `FeatureBuilder.Build(Plot) → PlotFeatures`:
    - pH: farmer `SoilTest.PhH2OEstimate()` overrides SoilGrids `PhH2O.Median`. Emit a Reason saying which source was used.
    - AWC (mm/m) via the Saxton & Rawls (2006) pedotransfer equations: field capacity minus wilting point, using sand, clay and organic matter (OM% = SOC g/kg × 0.1724). Implement from the paper and cite it in a comment. Unit-test against a few published texture-class values within tolerance.
    - `PhBufferCaOPerUnit` from the settings formula.
- `Et0Calculator`: if `DailyWeather.Et0Mm` is null, compute Hargreaves–Samani ET0 (FAO-56 eq. 52) with extraterrestrial radiation from latitude and DOY (FAO-56 eqs. 21–25). Test against a FAO-56 worked example.
- `SeasonCalendar`: maps a crop and a harvest year onto concrete dates.
    - Winter crops: sown in year Y−1 (`SowWindow`), harvested in Y. With 25 climate years, winter crops can be evaluated on 24 seasons; record this in the `Reason`.
    - Stage boundaries come from the sow date plus `StageLengthsDays`.
    - The flowering window is the mid stage, or the settings fallback fraction of the season.
- `WaterBalance` (daily FAO-56 single-coefficient bucket) per crop per climate year:
    - TAW = AWC × rootDepth. RAW = p × TAW. Start the bucket full at sowing.
    - Kc interpolated linearly across stages.
    - Ks = 1 if depletion ≤ RAW, otherwise (TAW − Dr)/(TAW − RAW).
    - Output the water stress index = 1 − Σ(Ks·Kc·ET0) / Σ(Kc·ET0), weighted ×2 in the mid stage.
    - If `FarmerInputs.HasIrrigation`, set the stress index to 0 and emit a Reason.
    - If `WaterProfile` is null, fall back to comparing seasonal precipitation with `SeasonWaterNeedMm`.

### Phase 3: Static survival (precomputed once per plot)

For each crop c and each climate year y, `StaticSuitabilityScorer` computes these factors in [0, 1]:

| Factor | Computation |
|---|---|
| texture | `Suitability.SandPct.Score(sand)` combined with `ClayPct` |
| heat | `HeatDaysAbove30AtFlowering.Score(count of days TMax > 30 in the flowering window)` |
| winterkill | Winter and perennial crops only. 0 if any day between sowing and the end of March has TMin < `WinterMinC` while snow depth < threshold, or TMin < `WinterMinCWithSnow` while snow is present. Otherwise 1. If snow data is missing, assume no snow and emit a warning. |
| water | `settings.survival.waterStressToScore` applied to the water stress index |

Combine the factors with the configured aggregator (min or geometric mean). Cache the result as `StaticSurvival[crop][year]` along with the factor breakdown; the breakdown feeds `CropScreeningResult` ("why lupin scores 0.4: water 0.4 in dry years").

`SurvivalAggregator`: mean and CVaR (mean of the worst ⌈cvarFraction·n⌉ values).

**Screening:** a crop is a candidate if its static CVaR ≥ the lowest `SurvivalFloor` among the requested strategies and the farmer has not excluded it. Catch crops are screened the same way, but with no flowering heat factor.

### Phase 4: Season simulator (the core)

`SeasonSimulator.Step(SoilState s, SeasonContext ctx) → (SoilState next, SeasonEvaluation eval, IReadOnlyList<Reason>)`. The step order matters; implement it exactly and test each step:

1. **Evaluate** the main crop against the inherited state `s`:
    - For each climate year: `survival(c,y) = StaticSurvival[c][y] × Π over Survival responses of curve(s[var])^weight`.
    - `yieldFactor = Π over Yield responses of curve(s[var])^weight`.
    - `penalty = Σ over Penalty responses of (1 − curve(s[var])) × weight`.
    - Add `InteractionOverride`s matching (previous main crop, this crop) to the corresponding target.
    - Aggregate the survival values into mean and CVaR.
    - Emit one Reason per response whose curve value is below 0.999. Include `CausedBy`: the seasons whose effects contributed most to that variable, tracked through a per-variable contribution ledger kept alongside the state.
2. **Reset Event variables** to their defaults, then **consume Pools**: reset every pool variable to its default. Pools are consumed by the main crop that has just been evaluated.
3. **Apply effects** in this order: main crop, catch crop, planned actions. Rules:
    - `ScaleBy` ("management.nRate"): the amount is scaled by actual ÷ default N rate. Actual equals default unless the plan overrides it; keep the hook.
    - `When` is evaluated by a small `ConditionEvaluator`. Supported conditions: `residue.<incorporate|remove|mulch>`, `farmer.hasLivestockOrManure`, `farmer.hasIrrigation`. An unknown condition is a validation error in phase 1.
    - `Add` adds to the value, `Multiply` multiplies it, `Set` overwrites it. `Load` accumulates into a per-season **load buffer**; it does not change the state yet.
4. **End of season:**
    - Pressures: `p = clamp(p × decayPerYear + loadBuffer[p])`.
    - Then run the settings `transforms` (e.g. pH −= acidificationCaO / buffer), resetting the source variable if `resetFrom` is set.
    - Clamp everything.

`HistorySeeder`: start from `SoilState.Initial(registry, var => fromPlot)` and run `Step` over `Plot.History` (oldest first, using the recorded catch crop, residue and actions; null residue means the crop default). Scale each season's loads and additive effects by `HistoricSeason.Certainty`. Ignore survival evaluation during seeding. A history crop that isn't in the knowledge base is skipped with a warning. With no history, use the initial state and emit a "no history: neutral start" warning.

### Phase 5: Objectives

`ObjectiveScorer` scores a plan on the **last unrolled cycle** (steady state). The transition seasons count only towards constraints and survival. Each objective is normalised to [0, 1], higher is better:

| Objective | Definition |
|---|---|
| Survival | mean over cycle seasons of `SurvivalCvar20 × yieldFactor` |
| Humus | mean annual change of `humusC` over the cycle → `humusPerYearToScore` |
| Pathogen | mean over seasons of the pressure values the season's crop responds to, weighted by response weight → `pathogenPressureToScore` |
| Nitrogen | mean over seasons of `min(1, residualN_before / max(1, crop.Management.NRateKgHa))`, or 1 if the N rate is 0 |
| Cover | mean `soilCoverWinter` after each season's effects |
| Structure | `compactionToScore(final compaction)` averaged with root-depth diversity (distinct 0.5 m root-depth classes in the cycle ÷ 3, capped at 1) |
| Water | mean over seasons and years of (1 − water stress index) |
| GrossMargin | not implemented: return "missing". Strategy selection renormalises the weights over the objectives that are present. |

Subtract the season penalties (step 1) from the Survival objective. Clamp the result to ≥ 0.

### Phase 6: Search

`RotationSearch`, for each cycle length L in [min(strategy.MinCycleYears), max(strategy.MaxCycleYears)] across the requested strategies:

1. **Depth-first search over the unrolled sequence** `history ⊕ transition (0..maxTransitionYears) ⊕ cycle (L seasons)`. Carry the simulated `SoilState` down the recursion; never re-simulate a prefix.
2. **Incremental hard constraints**, checked when a season is appended (`ConstraintChecker`, each violation produces a Reason):
    - Timing: if the next main crop is a winter crop, prev harvest DOY (`HarvestWindow.End`) + `soilPrepDays` ≤ next `SowWindow.End` in the same calendar year. Spring crops are always feasible after a non-perennial. For a perennial stand, consecutive repeats up to `MaxConsecutiveYears` count as one stand.
    - `MinReturnYears` across the history and the whole unrolled plan, including the cycle wrap-around.
    - `MaxConsecutiveYears`.
    - Dynamic survival CVaR ≥ strategy floor (use the lowest floor during the search, filter per strategy afterwards).
    - Farmer exclusions.
    - Group shares (`constraints.groupShares`) evaluated on the cycle.
3. **Cycle closure:** when the cycle is complete, simulate `unrollCycles` repetitions so the wrap-around transition (last → first) is evaluated with the correct state. Then score the plan.
4. **Deduplication:** two cycles that are rotations of each other are only the same plan when there is no history and no transition. Canonicalise in that case only (lexicographically smallest rotation by crop id).
5. **Pruning:** branch-and-bound. An optimistic upper bound for each objective is the best value achievable if all remaining seasons scored 1 on survival. Prune a branch if it can't enter the top K of any strategy and can't enter the Pareto archive. Keep it simple at first: survival-floor pruning plus a cheap upper bound on the weighted score.
6. **Second pass, `CatchCropAndActionOptimizer`** (for the best candidates only): for each gap between seasons, a catch crop is feasible if the next main crop is a spring crop and `prev harvest + soilPrepDays + catchCropMinGrowthDays ≤ min(DOY 300, catch crop SowWindow.End + its growing period)`. Choose the best catch crop (or none) and the best actions (each `ManagementActionDefinition` whose `RequiresFarmerInput` holds) by hill climbing over `localSearchPasses`. Accept a change only if it improves the strategy score without breaking a constraint. Re-simulate the whole plan after each accepted change.
7. **Parallelism:** `Parallel.ForEach` over the first-level branches with thread-local archives, merged deterministically.

`ParetoArchive`: keeps non-dominated `PlanEvaluation`s (using `ObjectiveScores.Dominates` over the objectives that are present).

`StrategySelector`:
- `WeightedSum`: Σ wᵢ·scoreᵢ over Pareto members that pass the strategy's survival floor.
- `Knee`: the member with the minimum weighted Euclidean distance to the ideal point (1, …, 1) after per-objective min-max normalisation across the front.
- Alternatives: the next best members whose crop-set Jaccard distance to the already chosen plans is ≥ `minAlternativeJaccardDistance`.

Performance target: < 2 s on a laptop for 20 crops, cycle length ≤ 5, 25 climate years, 3 strategies. Add a benchmark test (skipped by default) with a generated 20-crop knowledge base.

### Phase 7: Explanations and reports

- `ReasonCollector`: aggregates Reasons per plan. Merge identical codes per season and sort by |Delta|. Expose `TopReasons(n)` per season and per plan.
- `CropScreeningResult` per crop: candidate yes/no, static mean and CVaR, factor breakdown, worst years.
- `PredecessorMatrixReport`: for every main-crop pair (prev, next), start from a neutral state, run prev's season, evaluate next, and record next's score. Compare with `PredecessorRating.BestBefore`/`WorstBefore`: a pair in `BestBefore` should rank in the top third of next's predecessors, and one in `WorstBefore` in the bottom third. Output a CSV and a list of disagreements. Add a test that runs the report on the fixture; agreement must be ≥ the threshold in settings (start at 0.6).

---

## 4. Test fixture (build it in phase 1)

Create a synthetic knowledge base under `tests/.../Fixtures/kb/`. **Do not use real agronomic data in unit tests.** Suggested fake crops:

- `cerealA` (winter, hosts `pathogen:p1`, susceptible to p1)
- `cerealB` (spring, weak p1 host)
- `legumeA` (spring, adds `residualN`, hosts `pathogen:p2`, likes low pH)
- `rootCropA` (spring, strong humus loss, hosts `nematode:n1`)
- `oilseedA` (winter, hosts `pathogen:p3` with slow decay, `minReturnYears` 4)
- `catchA` (catch crop, +cover, +humus)

Plus one action `lime`. Golden scenarios with hand-checkable expectations:

- cerealA after cerealA scores lower than cerealA after legumeA.
- oilseedA never appears twice within 4 years, including across the wrap-around and history.
- `legumeA` in the last history season raises `residualN` for plan season 1.
- The soil-health strategy contains ≥ as many legume/catch seasons as the survival strategy.
- With a dry climate fixture, crops with high Kc are screened out with a water-factor Reason.
- Determinism: two runs give identical serialized results; shuffling the crop order in the input gives the same result.

---

## 5. Definition of done

- Every phase has passing tests. `dotnet build` produces no warnings in the engine (treat warnings as errors in the Engine project).
- The architecture test (no crop-specific literals) passes.
- `RecommendationService.Recommend` works end to end on the fixture and on `samples/plot-52.2-21.48.json`. Create that sample by mapping this real pipeline output: sand 77.5%, clay 9%, silt 13.4%, pH(H2O) 5.75, SOC 15.3 g/kg. Generate synthetic daily weather for 25 years from the monthly normals if real daily data isn't available yet, and mark the sample as synthetic.
- A short `docs/engine.md` explains the step order, the settings and how to add a crop without touching code.

## 6. Working rules

- Phases in order: **1 Build/Load/Validate → 2 Features/Climate → 3 Static survival → 4 Simulator + history → 5 Objectives → 6 Search → 7 Explanations**.
- After each phase, run all tests and summarise: what was built, any domain changes, open questions, and where you deviated from this spec and why.
- If a formula here is ambiguous or agronomically wrong, say so and propose an alternative instead of guessing silently.
- Keep services small and individually testable. No static mutable state. No hidden defaults: if a value isn't in the knowledge base or the settings, fail validation.