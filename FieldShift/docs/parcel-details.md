# Parcel details API (for the frontend)

Everything the backend knows about one registered parcel, from the field data providers of its country, in one
answer. Today: Poland (GUGiK national services) plus ISRIC SoilGrids worldwide. The answer has the same shape for
every country; a country without a source for some kind of data gets `"status": "notSupported"` there.

## Endpoints

| Request | Meaning |
|---|---|
| `GET /api/parcels/details?lat={lat}&lon={lon}` | The parcel at a point (the user tapped the map) |
| `GET /api/parcels/{id}/details` | The parcel with a register id, e.g. `141205_2.0008.60` |

Responses: **200** `ParcelDetailsResponse`; **400** bad coordinates or id; **404** no registered parcel there;
**502** the parcel register (ULDK) did not answer. A source that fails does **not** fail the request: its
section says `"unavailable"`.

Speed: the first call for a parcel takes ~2–10 s (SoilGrids is the slowest); later calls answer from the
PostgreSQL cache in under a second (only the parcel lookup is live).

## Response

```ts
interface ParcelDetailsResponse {
  countryCode: string;              // "PL"
  parcelId: string;                 // "141205_2.0008.60"
  location: { lat: number; lon: number }; // a point inside the parcel
  outlineAreaHa: number | null;     // area of the drawn outline
  landRegistry: Section<LandRegistryInfo>;
  soilMap: Section<SoilMapInfo>;
  terrain: Section<TerrainInfo>;
  soilProperties: Section<SoilProfile>; // same shape as `soil` of /api/field-profile
  generatedAtUtc: string;
}

interface Section<T> {
  status: "ok" | "noData" | "unavailable" | "notSupported";
  data: T | null;                   // only with "ok"
  provider: string | null;          // e.g. "pl.egib.v1"
  fetchedAtUtc: string | null;      // when the source was asked (older when cached)
  fromCache: boolean;
}

interface LandRegistryInfo {        // Poland: EGiB (land register), per parcel
  source: string;
  areaHa: number | null;            // area in the register
  place: string[];                  // voivodeship, county, commune, precinct
  classes: {
    code: string;                   // "RIVb", "LzrRIVa", "ŁIII", "dr", ...
    landUse: string;                // "grunty orne", ...
    qualityClass: string | null;    // "IVb" (soil quality class I–VI, a/b, VIz)
    qualityName: string | null;     // "orne średnie gorsze"
  }[];
  publishedOn: string | null;       // "2026-11-13"
}

interface SoilMapInfo {             // Poland: mapa glebowo-rolnicza 1:5000
  source: string;
  complexCode: string | null;       // "5"
  complexName: string | null;       // "kompleks żytni dobry"
  soilTypeCode: string | null;      // "A"
  soilTypeName: string | null;      // "gleby bielicowe i pseudobielicowe"
  texture: { code: string; name: string; from: string | null }[]; // top first; from = "50–100 cm"
  surveyedOn: string | null;        // often the 1960s–70s
}

interface TerrainInfo {             // Poland: GUGiK terrain model, 1 m grid
  source: string;
  elevationMinM: number; elevationMeanM: number; elevationMaxM: number;
  slopePct: number;                 // slope of the plane fitted to the samples
  slopeClass: string;               // "płasko" | "łagodny spadek" | "umiarkowany spadek" | "stromo"
  samples: number;                  // up to 150 points inside the parcel
}
```

## Sources (Poland)

| Section | Service | Cached for |
|---|---|---|
| parcel lookup | ULDK `uldk.gugik.gov.pl` (not cached) | – |
| `landRegistry` | Krajowa Integracja Ewidencji Gruntów (WMS GetFeatureInfo), passes the request to the county | 30 days |
| `soilMap` | Mapa glebowo-rolnicza WMS, layer `KONTURY_GLEBOWE` (Geoportal "Rolnictwo" module) | 180 days |
| `terrain` | `services.gugik.gov.pl/nmt` `GetHByPointList` | 365 days |
| `soilProperties` | ISRIC SoilGrids (worldwide, ~250 m model) | 180 days |

"No data" answers are cached for 1 day; failures are not cached.

Data notes:
- Some counties publish only the parcel's id and place to the national EGiB integration, without area or classes
  (seen in powiat poznański): `landRegistry` is then `"noData"`.
- Soil quality classes (I–VI) are the official per-parcel classification. They are **not** the agricultural
  suitability complexes; those come from the soil map (`soilMap.complexName`).
- The soil map is mostly from surveys of the 1960s–70s; show `surveyedOn`.

## Map tiles (`/api/map-tiles`)

`GET /api/map-tiles/{layer}/{z}/{x}/{y}.png`: 256 px Web Mercator tiles of a data layer for the app's map, through
our backend (the app never asks the source). `GET /api/map-tiles/{layer}/legend`: `[{ code, name, color }]`.

| Layer | Source | Zooms | Cached |
|---|---|---|---|
| `soil-map` | Mapa glebowo-rolnicza WMS (GetMap, EPSG:3857), Poland only | 13–19 | 30 days in `tile_cache` (PostgreSQL) |

Outside the provider's area, out of its zooms, or when the source fails (the WMS answers 503 now and then; the
HTTP client retries), the answer is a transparent tile with `max-age=300`, so the map shows nothing there and asks
again later. The legend colours are those of the WMS legend image (GetLegendGraphic); hatched areas (forest,
built-up) have no single colour and are not in it.

A new layer or country = an `IMapTileProvider` (layer id, zooms, `Covers`, legend) registered in DI.

## Adding a country

1. Implement `ICountryProvider` (`GetFieldAtAsync`, `GetFieldByParcelIdAsync`): find the parcel, return a
   `FieldLocation` with its id, a point inside and the outline in the country's metric grid.
2. Implement the providers the country has: `ILandRegistryProvider`, `ISoilMapProvider`, `ITerrainProvider`
   (or `ISoilPropertiesProvider` to replace SoilGrids there). `Supports` checks the country code; `Id` names the
   cache namespace (bump its version when the result shape changes).
3. Register them in the country's `Add…()` extension. Nothing else changes: `ParcelDetailsService` picks the first
   provider that supports the parcel, and `FieldDataCache` caches it.
