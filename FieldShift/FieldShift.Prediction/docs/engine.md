# Decision engine: how it works

Short guide for people who work on or with `FieldShift.Prediction`. The full specification is `impl.md`.

## One call

```csharp
var loaded = KnowledgeBaseLoader.Load("Data");          // crops, state variables, strategies, engineSettings.json
var result = RecommendationService.Recommend(plot, loaded.KnowledgeBase!, loaded.Settings!);
```

`result.Recommendations` has one entry per strategy (best plan plus alternatives, each with reasons).
`result.Screening` says why each crop was or was not a candidate. `result.Warnings` lists data gaps
(no snow data, estimated ET0, no history, ...). Same input gives the same output: nothing depends on thread count,
input order, culture or the clock (the clock only stamps `GeneratedAtUtc`).

## Pipeline

1. **Validate** the knowledge base and settings (`Engine/Validation`). Anything missing or inconsistent fails here;
   there are no hidden defaults.
2. **Plot features** (`Features`): soil texture, pH, organic carbon, water capacity (Saxton & Rawls 2006), lime buffer.
3. **Climate** (`Climate`): daily weather per year, ET0 (Hargreaves-Samani when not supplied).
4. **Screening** (`Survival`): for every crop and every climate year, a survival score from texture, heat, winterkill
   and a water bucket (FAO-56). The crop's score is the mean of the worst 20 % of years (CVaR). Crops below the lowest
   strategy floor are dropped, with a reason. With `survival.recencyHalfLifeYears` set, newer years weigh more in the
   mean and the CVaR (the tail is the same share of years, taken by weight). This is only less reliance on old weather,
   not a climate forecast: there is no trend or projection.
5. **History** (`Simulation/HistorySeeder`): past seasons are run through the simulator to get the starting soil.
6. **Search** (`Search`): depth-first search over rotations, then pruned and ranked per strategy (see below).
7. **Catch crops and actions** (`Search/CatchCropAndActionOptimizer`): hill climbing on the chosen plans.
8. **Explain**: reasons per season, merged and ranked by `ReasonCollector`.

## One season, in this order (`SeasonSimulator.Step`)

1. Evaluate the main crop against the inherited soil state: survival, yield factor, penalties, interaction overrides.
2. Reset *event* variables to their defaults and consume *pool* variables.
3. Apply effects of the main crop, the catch crop and the planned actions. Pressure loads wait in a buffer.
4. End of season: pressures decay and take their loads, then the `transforms` from settings run (for example
   acidification changes pH), then every variable is clamped to its range.

State variable kinds: **stock** (persists), **pool** (consumed each season), **pressure** (decays, e.g. pathogens),
**event** (one season only).

## Objectives and search

Plans are unrolled `search.unrollCycles` times (now 4) and scored on the last cycle, so slow pressures build up before
they are judged. Seven objectives are scored (survival, soil carbon, nitrogen, cover, water stress, pressure,
structure). Gross margin is not scored: there is no price data.

Hard rules prune the search: sowing/harvest timing, `minReturnYears` (also across the wrap-around and the history),
`maxConsecutive`, farmer exclusions, group shares (for example at most 67 % cereals) and the strategy's survival floor.
Every violation is a `Reason` with a stable code.

A strategy is either `WeightedSum` (weights over objectives) or `Knee` (closest to the ideal point on the Pareto front).
Alternatives must differ in crop set by at least `minAlternativeJaccardDistance`.

## Settings (`Data/engineSettings.json`)

| Section | Controls |
|---|---|
| `calendar` | soil preparation days, catch-crop minimum growth days and latest end day |
| `winter` | snow depth that protects winter crops |
| `survival` | factor aggregation, CVaR share, thresholds |
| `transforms` | end-of-season links between variables (for example acidification to pH) |
| `objectives` | how each objective is computed from the state |
| `constraints` | group shares and other hard-rule parameters |
| `search` | `unrollCycles`, `maxTransitionYears`, `bridgeCropsPerStart`, `topKPerStrategy`, `alternativesPerStrategy`, `minAlternativeJaccardDistance`, `localSearchPasses` |
| `pedotransfer`, `phBuffer`, `soil` | soil physics constants |
| `survival.recencyHalfLifeYears` | newer climate years count more in a crop's mean survival and CVaR (weight = 0.5 ^ (years before the latest / half-life)); leave it out for equal weights. Shipped: 6 |
| `interactions` | `maxMultiplier`: cap for the combined factor of all state-interaction rules on one target (default 3) |
| `explain` | how many causes a reason lists |
| `report` | `minPredecessorAgreement` for the predecessor report |

## Add a crop without touching code

1. Copy a similar crop file, or add an entry to `crops.json`. Set `id`, `type` (`winter`, `spring`, `perennial`,
   `catch`), `tags`, `sowWindow` and `harvestWindow` (day of year).
2. `suitability`: ranges for texture, heat days, water need (`absMin/optMin/optMax/absMax`).
3. `water`: `kc` per stage, `stageLengthsDays`, `rootDepthM`, `depletionFraction`.
4. `responses`: how the crop reacts to state variables (curve of 0..1 yield multiplier).
5. `effects`: what it leaves behind (`add`, `set`, `load` ...). A crop that hosts a pathogen loads that pressure.
6. `hardRules` (`minReturnYears`, `maxConsecutive`) and, if known, `predecessorRatingIUNG`.
7. Give every number a `source`. If it is an estimate, say so (`confidence`); the interface shows it.
8. Run the tests. The validator names anything missing, and the predecessor report shows if the new crop's
   neighbours agree with the rating.

A new state variable goes into `stateVars.json`; if it needs an end-of-season link, add a `transforms` entry.
No agronomy lives in code: an architecture test fails if a crop name appears in the engine's source.

## State interactions ("when A is high, B is stronger")

`Data/stateInteractions.json` (optional) holds hand-written rules. They are separate from `interactions.json`, which
is the previous-crop → next-crop override list.

```json
{ "id": "highN_eyespot",
  "when":   { "var": "residualN", "curve": [[60, 0], [150, 1]] },
  "target": { "kind": "effect", "var": "pathogen:eyespot", "op": "load" },
  "multiplier": 1.5, "crops": "tag:cereal", "source": "EST", "confidence": "expert_estimate" }
```

- The trigger is a state variable at the **start** of the season (the inherited soil), mapped to 0..1 by the curve.
  The factor is `1 + (multiplier - 1) × trigger`. A multiplier below 1 weakens.
- `kind: "effect"` scales the amount of the owner's Add/Load effect on `var` (`op` limits it to one of the two).
  `kind: "response"` scales the **loss** `1 - curve` of the crop's response to `var`, so the result stays in 0..1.
- `crops` limits the rule to matching crops (the crop that owns the effect, or the crop that responds).
- Rules on the same target multiply; the product is capped at `interactions.maxMultiplier`.
- A rule that changes something adds a `Reason` of kind `StateInteraction`, code `interaction.rule.<id>`, value = the
  factor. The Web layer forwards `interaction.*` codes; the app shows nothing for a code it has no text for yet.
- The validator rejects unknown variables, multipliers outside `(0, maxMultiplier]`, bad `op`s and duplicate ids,
  and warns when no matching crop has the effect or response (the rule would never fire).
- The shipped rules are expert estimates and need agronomic review, like `crops.json`.

## Reports

`PredecessorMatrixReport.Build(env)` scores every crop after every other crop from a neutral soil, writes a CSV
(`ToCsv()`) and lists pairs that contradict the crops' `predecessorRatingIUNG` (best before should rank in the top
third, worst before in the bottom third; ties count as the middle rank). Agreement must reach
`report.minPredecessorAgreement` on the synthetic fixture. On the real knowledge base it is information for the
agronomists, not a gate.

## Known limits

- Agronomic values in `crops.json` and `stateVars.json` are mostly expert estimates (`confidence`).
- Climate is a sample of past years (NASA POWER 2014 onwards, about 12 years). There is no trend, projection or
  climate-change scenario; recency weighting only shifts weight to newer years.
- Cycles are unrolled 4 times: a close approximation of steady state, not a proof.
- With a crop history, transitions are limited to short bridges (`bridgeCropsPerStart`) to keep the search fast.
- `PreferredCrops` and `Priorities` from the farmer are not used yet.
- `samples/plot-52.2-21.48.json` has real soil values but synthetic weather. Do not present its results as findings.
