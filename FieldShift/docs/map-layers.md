# Map layers API (for the frontend)

Monthly time series of climate and soil layers for one point, with legends, ready for a map with a layer switcher,
a date slider and a legend. One response has everything: pick a layer → slider index `i` → `layer.values[i]` →
colour from `layer.legend`.

Base URL in development: `http://localhost:5066`.

## Endpoints

### `GET /api/map-layers`

| Param | Required | Format | Default |
|---|---|---|---|
| `lat` | yes | −90…90 | |
| `lon` | yes | −180…180 | |
| `from` | no | `yyyy-MM` | January, 10 full years ago (today 2026-11 → `2016-01`) |
| `to` | no | `yyyy-MM`, at most the last full month | December of last year (`2025-12`) |
| `layers` | no | comma-separated ids | all layers |

Max range 15 years, earliest month `1981-01`.

Responses:

- **200** `MapLayersResponse`.
- **400** `ValidationProblemDetails` with Polish messages in `errors` (key = parameter name).
- **502** `ProblemDetails`: NASA POWER unavailable.

Headers: `Cache-Control: public, max-age=3600`; responses are gzip/brotli compressed (10 years ≈ 16 kB → 7 kB).
The first call for a new point takes ~5–10 s (NASA POWER + SoilGrids); repeated calls come from a 24 h server cache.

### `GET /api/map-layers/grid`

The same monthly layers for a **5 × 5 block of NASA POWER cells** around a point, to draw the area as a heat map.
A cell is 0.5° latitude × 0.625° longitude (MERRA-2 grid, about 55 × 43 km in Poland), so the block is about
250 km wide. The middle cell is the one that contains the point, and its values are exactly what
`/api/map-layers` returns for that point (NASA POWER gives every point of a cell the same values).

Parameters as in `/api/map-layers`. `layers` may only name layers that come from NASA POWER alone: `temperature`,
`heatStress`, `frostRisk`, `precipitation`, `extremeRain`, `soilMoisture`, `plantStress` (the default is all of
them). Soil and `erosionRisk` (depends on the field's soil) are point-only, because SoilGrids answers only a few
requests per minute; `evaporation` is not on the grid either.

Responses: **200** `MapLayersGridResponse`; **400** as above (also for a layer the grid does not have); **502** when
NASA POWER did not answer for any cell. A cell NASA did not answer for has only `null` values and the response gets
a warning; such a response is cached for 10 minutes only.

The first call for a block takes ~5–15 s (25 NASA POWER requests, at most 10 at a time for all users together);
repeated calls come from a 24 h server cache. Points in the same cell share one block. 10 years ≈ 70 kB of JSON.

```ts
interface MapLayersGridResponse {
  center: { lat: number; lon: number };   // centre of the point's cell
  cellSize: { lat: number; lon: number }; // 0.5, 0.625
  rows: number; cols: number;             // 5, 5 (row 0 = south, col 0 = west)
  period: { from: string; to: string };
  dates: string[];                        // "yyyy-MM", like /api/map-layers
  defaultIndex: number;                   // latest month
  cells: { row: number; col: number; lat: number; lon: number }[]; // cell centres; off-globe cells left out
  layers: {
    id: string; name: string; unit: string; decimals: number;
    isEstimate: boolean; source: string;
    legend: Legend;                       // same as in /api/map-layers
    values: (number | null)[][];          // values[cellIndex][monthIndex], cells in the order of `cells`
  }[];
  warnings: string[];                     // Polish
  generatedAtUtc: string;
}
```

### `GET /api/map-layers/definitions`

`LayerDefinition[]` with no data. Use it to build the layer switcher and legends before the data arrives.

## Layers

| order | id | name | unit | group | estimate |
|---|---|---|---|---|---|
| 1 | `temperature` | Temperatura | °C | Klimat | |
| 2 | `heatStress` | Stres cieplny | dni | Klimat | |
| 3 | `frostRisk` | Ryzyko mrozu | dni | Klimat | |
| 4 | `precipitation` | Opady | mm | Woda | |
| 5 | `extremeRain` | Ekstremalne opady | dni | Woda | |
| 6 | `soilMoisture` | Wilgotność gleby | 0–1 | Woda | |
| 7 | `evaporation` | Parowanie | mm | Woda | |
| 8 | `plantStress` | Stres roślinny (szacunek) | 0–100 | Rośliny i gleba | yes |
| 9 | `erosionRisk` | Ryzyko erozji (szacunek) | 0–100 | Rośliny i gleba | yes |

Only `temperature`, `precipitation` and `soilMoisture` have `anomalies` + `anomalyLegend` (difference from the
same calendar month's average). `isEstimate: true` layers must be shown with an "estimate" label (project
accessibility/honesty rules). Show `source` next to every value.

## TypeScript types

```ts
export interface LegendStop {
  /** Exclusive upper bound in the layer unit; null for the last stop. */
  max: number | null;
  /** "#RRGGBB" */
  color: string;
  /** Polish label with the range, e.g. "sucho (20–40 mm)". */
  label: string;
}

export interface Legend {
  type: "sequential" | "diverging";
  /** Ascending by max; the last stop has max = null. */
  stops: LegendStop[];
}

export interface LayerDefinition {
  id: string;
  name: string;
  unit: string;
  group: string;
  order: number;
  /** Values are already rounded to this many decimals; format with the same precision. */
  decimals: number;
  isEstimate: boolean;
  source: string;
  description: string;
  legend: Legend;
  anomalyLegend: Legend | null;
}

export interface LayerStats {
  min: number | null;
  max: number | null;
  mean: number | null;
  /** Unit per 10 years, from complete years only; null with < 2 complete years. */
  trendPerDecade: number | null;
}

export interface LayerSeries extends LayerDefinition {
  /** Same length as MapLayersResponse.dates; null = no data that month. */
  values: (number | null)[];
  /** temperature / precipitation / soilMoisture only; otherwise null. */
  anomalies: (number | null)[] | null;
  /** temperature: { max, min } (°C); extremeRain: { maxDailyMm } (mm); otherwise null. */
  extra: Record<string, (number | null)[]> | null;
  stats: LayerStats;
}

export interface MapLayersResponse {
  location: { lat: number; lon: number };
  period: { from: string; to: string };
  granularity: "month";
  /** "yyyy-MM", ascending. */
  dates: string[];
  defaultLayerId: string;
  /** Start the slider here (latest month). */
  defaultIndex: number;
  layers: LayerSeries[];
  static: {
    soil: {
      source: string;
      soilClass: "Lekka" | "Średnia" | "Ciężka" | null;
      sandPct: number | null;
      clayPct: number | null;
      ph: number | null;
    } | null;
    terrain: { source: string; slopePct: number; slopeClass: string } | null;
  };
  /** Polish notes to show the user. */
  warnings: string[];
  generatedAtUtc: string;
}
```

## Example

```ts
const API = "http://localhost:5066";

export async function fetchMapLayers(
  lat: number,
  lon: number,
  opts: { from?: string; to?: string; layers?: string[] } = {},
): Promise<MapLayersResponse> {
  const params = new URLSearchParams({ lat: String(lat), lon: String(lon) });
  if (opts.from) params.set("from", opts.from);
  if (opts.to) params.set("to", opts.to);
  if (opts.layers?.length) params.set("layers", opts.layers.join(","));

  const res = await fetch(`${API}/api/map-layers?${params}`);
  if (!res.ok) {
    const problem = await res.json().catch(() => null);
    // 400: problem.errors = { from: ["..."], ... } (Polish); 502: problem.detail
    throw new Error(problem?.detail ?? Object.values(problem?.errors ?? {}).flat().join(" ") ?? res.statusText);
  }
  return res.json();
}

/** Colour of a value: the first stop with value < max; the last stop (max = null) catches the rest. */
export function colorFor(legend: Legend, value: number | null): string | null {
  if (value === null) return null; // draw "no data" (e.g. grey hatch), not a colour from the scale
  for (const stop of legend.stops) {
    if (stop.max === null || value < stop.max) return stop.color;
  }
  return legend.stops[legend.stops.length - 1]?.color ?? null;
}

// Usage with the slider:
const data = await fetchMapLayers(52.2, 21.48);
let layer = data.layers.find((l) => l.id === data.defaultLayerId)!;
let i = data.defaultIndex;
const value = layer.values[i];
const color = colorFor(layer.legend, value);
const anomalyColor = layer.anomalies && layer.anomalyLegend
  ? colorFor(layer.anomalyLegend, layer.anomalies[i])
  : null;
console.log(data.dates[i], layer.name, value?.toFixed(layer.decimals), layer.unit, color);
```

`colorFor` matches the backend logic in `LayerDefinitions.StopFor` (covered by unit tests, including boundary
values: `20` mm falls into "sucho (20–40 mm)", not "bardzo sucho").

## Data notes

- NASA POWER is a ~50 km grid: one value for the whole area around the field, not field-level.
- Months with partly missing days are computed from available days; sums and day counts are scaled to the full month.
- `evaporation` is actual evapotranspiration from the model (EVPTRNS, MJ/m²/day × 0.408 = mm). Dry soil
  evaporates less, so low summer values can mean drought, not "no water demand".
- `erosionRisk` uses terrain slope only for locations listed in `DemoLocations` (appsettings, slope from SRTM via
  NASA AppEEARS, matched within 2 km); otherwise slope factor 1.0 and a warning.
