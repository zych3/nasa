# FieldShift backend (.NET)

ASP.NET Core Web API (controllers, .NET 10) for the Field Shift app.

## Requirements

- .NET SDK 10 (`dotnet --list-sdks` must show `10.x`). If your default `dotnet` is older but you have SDK 10 in
  `~/.dotnet`, call `~/.dotnet/dotnet` instead of `dotnet` in the commands below.

## Run

```bash
cd FieldShift/FieldShift.Web
dotnet run --launch-profile http      # http://localhost:5066
```

OpenAPI document (Development only): http://localhost:5066/openapi/v1.json

## Tests

```bash
cd FieldShift
dotnet test
```

`FieldProfileServiceTests` run offline on JSON fixtures in `FieldShift.Web.Tests/Fixtures/`.
`XmlParserTests` call live GUGiK services and need internet access.

## Field profile endpoint

`GET /api/field-profile?lat={lat}&lon={lon}`: climate (NASA POWER climatology) plus topsoil 0–30 cm
(ISRIC SoilGrids) for one point, with a plain-language Polish summary.

```bash
curl "http://localhost:5066/api/field-profile?lat=52.20&lon=21.48"
```

| Status | When |
|---|---|
| 200 | Profile returned. `soil` is `null` (with a message in `warnings`) when SoilGrids has no data or fails. |
| 400 | `lat` / `lon` missing or out of range (`ProblemDetails`). |
| 502 | NASA POWER unavailable: no profile without climate (`ProblemDetails`). |

How it works:

- `NasaPowerClient` and `SoilGridsClient` are typed `HttpClient`s with `AddStandardResilienceHandler`
  (retry + timeouts; SoilGrids gets 60 s in total because it is slow).
- `FieldProfileProvider` calls both APIs in parallel, caches the result in `IMemoryCache` for 24 h
  (10 min if soil failed). The cache key and upstream calls use coordinates rounded to 2 decimals (~1 km).
- `FieldProfileService` does all calculations (no HTTP), so it is unit-tested on fixtures.
- Config: `FieldProfile:NasaPowerBaseUrl` and `FieldProfile:SoilGridsBaseUrl` in `appsettings.json`.

Data notes: NASA POWER is a ~50 km grid, so climate is regional, not field-level. `minTempC` / `maxTempC` are
record extremes over the period, not averages, which is why `heatRiskMonths` can include months that are
rarely hot. SoilGrids is a 250 m model estimate that the farmer may correct.

Soil properties fetched: sand, clay, silt, pH, organic carbon, nitrogen, CEC, bulk density, coarse fragments.
The 0–5 cm layer of organic carbon and nitrogen is skipped when it is more than 2× the 5–15 cm layer
(typical model overestimate on arable land). CEC looks overestimated on sandy soils (≈ 22 cmol(c)/kg at
52.20, 21.48 where ~5–10 is typical for sand), so treat `cecClass` with care. Water retention (`wv0033`, `wv1500`)
is available in SoilGrids but is not used: values at the test point are implausible for sandy soil.
