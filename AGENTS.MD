# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo.

## Project

NASA Space Apps hackathon entry for the challenge **"Field Shift: Adapting Farms with NASA Data"**.
We build a decision-support tool that uses NASA Earth observations plus local soil data, crop traits and
farmer priorities to help farmers explore crop-rotation strategies that protect soil and adapt to a changing climate.

**Core principle: the interface must be usable by people who are not comfortable with technology.**
Simple, one question per screen, big touch targets, plain language, no jargon.

## Architecture

```
Flutter app (frontend/)  ->  .NET backend  ->  Decider (scoring)
                                   ^
                                   |
                         Dataflow / data fetching + cache  <-  external data (NASA POWER, soil, parcels...)
```

- **Frontend:** Flutter (Dart), in `frontend/`. Targets: web, Android (Linux desktop only for local dev).
- **Backend:** .NET. Owns data fetching, caching, scoring and the API contract.
- **Database:** PostgreSQL (`db/Dockerfile`), used for accounts and the field data cache through EF Core. The schema is the EF migrations in `FieldShift/FieldShift.Web/Migrations`; the backend applies them itself. Change the schema only by editing the entities and running `dotnet ef migrations add <Name>`, never by hand in SQL.
- **Accounts:** login (username, no e-mail) + password. Users and login sessions in the same PostgreSQL (`Accounts/AccountsDbContext.cs`, tables `users`, `user_sessions`, `saved_plans`, own migrations: `Migrations/Accounts`; connection `ConnectionStrings:Accounts`, falling back to `Prices`). Passwords are hashed with ASP.NET Core Identity's `PasswordHasher`; login returns a random token, only its SHA-256 is stored, valid `Accounts:SessionDays` (default 30). Mark endpoints that need a user with `[Authorize]` and read the id from the `NameIdentifier` claim; all other endpoints stay public. `Accounts:TestLogin` enables `POST /api/auth/test-login` (shared `test` account); the app shows its button in debug builds or with `--dart-define=TEST_LOGIN=true`. "My parcels" (`saved_parcels`) is a backup of the list the phone keeps (`MyParcelsStore`): the app sends its list, for each parcel the newer change wins; the active parcel is never synced. Saved rotation plans (`saved_plans`, one row per plan the user kept) hang off `users`; crop alerts will too. An account is never required to save a plan: plans live on the phone (`LocalPlansStore`, shared_preferences) and, when signed in, are also copied to `saved_plans`. On sign-in the phone and the account are merged (same goal, place and crops = one plan; plans deleted from the account elsewhere leave the phone; deletes the server missed are retried).
- **Field data providers:** each kind of data (land register, soil map, terrain, soil properties) has its own interface in `FieldShift/FieldShift.Web/FieldData/ProviderContracts.cs`; each country registers its implementations (Poland: `Countries/Poland/`). Services pick the first provider whose `Supports` says yes and ask it through `FieldDataCache`, which keeps answers in the PostgreSQL table `provider_cache` (own migrations: `Migrations/FieldData`). A new country = new providers, no change in the services. See `FieldShift/docs/parcel-details.md`.
- **Decider:** start as plain rule-based scoring behind an interface (`IDecider`). An ONNX model is optional and only if time and data allow.
- The frontend never talks to NASA or other data sources directly; it only calls our backend.

## Key concept: the plot (parcel)

- Everything is keyed by **`parcelId`**. Coordinates, addresses and parcel numbers are only inputs used to *resolve* a parcel.
- Flow: user gives address / parcel number / map tap -> `POST /api/parcels/resolve` -> `parcelId` + polygon + area -> all later calls use `parcelId`.
- If parcel lookup fails, fall back to a plot built from raw coordinates. Never block the user.

## API endpoints (draft contract)

| Purpose | Endpoint |
|---|---|
| Health check | `GET /health` |
| Resolve a parcel from address / coordinates / number | `POST /api/parcels/resolve` |
| Parcels in the visible map area | `GET /api/parcels?bbox=...` |
| Parcels nearest to a point (parcel at the point + parcels of nearest addresses) | `GET /api/parcels/nearby?lat=..&lon=..` |
| Parcel details: land register classes, soil map, terrain, modelled soil (sections with status and source) | `GET /api/parcels/details?lat=..&lon=..`, `GET /api/parcels/{id}/details` |
| Address hints while typing (`kind`: `place` / `street` / `address`; empty list for < 3 chars or no match) | `GET /api/parcels/suggest?q=...` |
| Parcel at a point (e.g. a chosen address hint; 404 when none) | `GET /api/parcels/at?lat=..&lon=..` |
| Clear long-term climate changes in the area of a parcel since 1981 (NASA POWER): at most 3 trends as means of the first and last 15 years, with long-term advice codes; `status` `ok` / `no_clear_trends` / `no_data`. Facts about the past, not a forecast; rules and thresholds in `FieldShift.Web/Data/climate-trend-rules.json` | `GET /api/parcels/climate-trends?parcelId=...` or `?lat=..&lon=..` |
| Risk indicators with source and confidence | `GET /api/parcels/{id}/indicators` |
| Climate (NASA POWER) + topsoil (SoilGrids) profile of a point | `GET /api/field-profile?lat=...&lon=...` |
| Monthly map layers with legends for a date slider | `GET /api/map-layers?lat=...&lon=...&from=yyyy-MM&to=yyyy-MM&layers=...` |
| Map layer definitions (no data) | `GET /api/map-layers/definitions` |
| Map colouring (best crop per parcel) | `POST /api/parcels/suitability` |
| Ranked rotation plans for one plot (body: `lat`, `lon` required; `pastCrops` (empty = first crop on the plot), `goal`, `excludedCrops`, `hasLivestock`, `hasIrrigation`, `soilPhKCl`, `parcelId` optional; answer: plans per goal, ratings, warnings as codes) | `POST /api/recommendations` |
| Crop catalogue (names, photo, area/yield, growing needs) | `GET /api/crops`, `GET /api/crops/{id}` |
| NASA satellites at a field, one part per call so each shows when ready (`rain`: GPM IMERG daily ~10 km; `soil`: SMAP L4 moisture / soil temperature 9 km with a normal from earlier years; `vegetation`: MODIS NDVI 250 m with this season vs normal; `surface-temperature`: MODIS LST 1 km; `evapotranspiration`: MODIS ET 500 m). Every part has `status` (`ok`, `noData`, `unavailable`, `notConfigured`), `source` and codes (`level`: `below` / `normal` / `above`) | `GET /api/satellite/{part}?lat=..&lon=..`, all parts: `GET /api/satellite?lat=..&lon=..` |
| Create an account (body: `username` 3–32 letters/digits/`._-`, `password` ≥ 8 chars; answer: `token`, `expiresAt`, `user` {`id`, `username`, `createdAt`}; errors: ProblemDetails with `code`: `invalid_username`, `password_too_short`, `password_too_long`, 409 `username_taken`, 503 `database_unavailable`) | `POST /api/auth/register` |
| Log in (same body and answer; 401 `invalid_credentials`) | `POST /api/auth/login` |
| Testing only: log in to the shared `test` account without a password (404 unless `Accounts:TestLogin` is true: Development, docker compose) | `POST /api/auth/test-login` |
| The logged-in user / end the session (header `Authorization: Bearer <token>`; 401 without a valid one) | `GET /api/auth/me`, `POST /api/auth/logout` |
| "My crops": the logged-in user's crops at their places, for a later risk check (Bearer token required, 401 without; each user sees only their own). List (newest first) / one / add (body: `cropId` from `/api/crops`, `latitude`, `longitude` required; `parcelId`, `label` ≤ 200, `isActive` default true; 201) / change (only sent fields: `cropId`, new place as `latitude` + `longitude` together, `parcelId` ("" removes it), `label` ("" removes it), `isActive`). Errors: `code` `invalid_crop`, `invalid_location`, `label_too_long`, `too_many_crops` (max 100), 404 `not_found` | `GET /api/my-crops`, `GET /api/my-crops/{id}`, `POST /api/my-crops`, `PATCH /api/my-crops/{id}` |
| Keep a rotation plan in the logged-in user's profile (body: `lat`, `lon`, `goal`, `plan` = the plan object as `POST /api/recommendations` returned it (needs a `cycle` array, max 64 KB); `parcelId`, `answers` optional; max 100 per user; errors: ProblemDetails `code`: `invalid_location`, `invalid_goal`, `invalid_plan`, `invalid_answers`, `too_many_plans`, 503 `database_unavailable`; 401 without a valid token) | `POST /api/me/plans` |
| Sync the logged-in user's "My parcels" (body: `items` = everything the device has: `parcelId`, `parcel` (the app's parcel object, not needed for a removal), `updatedAt` (set by the app), `deleted`; answer: `syncedAt` and the merged `items`. The newer `updatedAt` of each parcel wins, removals are kept 90 days so other devices remove the parcel too; max 100 parcels, 300 items; errors: ProblemDetails `code`: `invalid_parcels`, `too_many_parcels`, 503 `database_unavailable`; 401 without a valid token) | `POST /api/me/parcels/sync` |
| The logged-in user's saved plans, newest first (`limit` default 20, max 100) / remove one (204, 404 when it is not theirs) | `GET /api/me/plans`, `DELETE /api/me/plans/{id}` |

Keep this table and the example JSON in `frontend/assets/mock/` in sync with the backend.
Change the contract only after agreeing with both frontend and backend owners.

## Frontend conventions (Flutter)

- In Flutter we say **widget**, not component.
- Layout under `frontend/lib/`:
  - `main.dart`: app entry, theme
  - `app/`: router, theme
  - `api/`: `ApiClient` (the only place that does HTTP)
  - `models/`: data classes with `fromJson`
  - `screens/`: one file per full screen (e.g. `home_shell.dart`)
  - `widgets/`: reusable widgets (e.g. `app_nav_bar.dart`, `big_button.dart`, `choice_card.dart`)
  - `l10n/`: translations (`app_en.arb`, `app_pl.arb`), generated `app_localizations*.dart`, `language_options.dart`
- One widget per file, file names in `snake_case`, classes in `PascalCase`.
- Use **relative imports** inside `lib/`.
- Screens call a repository, never `ApiClient` directly. The repository returns mock data from `assets/mock/` when `useMock` is true, otherwise calls the backend.
- Look: **forui** (`lib/app/app_theme.dart`: calm "paper and forest" palette, Inter, touch sizes, light/dark like
  the phone). `main.dart` puts an `FTheme` above every route (`MaterialApp.builder`) and derives the Material theme
  from it, so forui widgets (`FCard`, `FButton`, `FAlert`, `FBadge`, ...) and Material widgets match. Do not remove
  that `FTheme`: forui widgets crash without it. Widget tests that show forui widgets need the same wrapper (see
  `test/widget_test.dart`). Button styles: set sizes on a theme text style (`textTheme.labelLarge?.copyWith(...)`),
  not `TextStyle(fontSize: ...)`, or the label loses the app font.
- NASA Earthdata (IMERG, SMAP): the backend reads the user token from `Earthdata__Token` (Docker: `EARTHDATA_TOKEN` in
  the git-ignored `.env`; `dotnet run`: `dotnet user-secrets set "Earthdata:Token" ...`). Never commit it or paste it
  in chats. Without it those parts answer `notConfigured` and the rest still works. The token expires after 60 days.
  The Earthdata app "NASA GESDISC DATA ARCHIVE" must be approved once (IMERG). MODIS comes from ORNL DAAC without a
  login. Values read from NASA are kept in PostgreSQL (`provider_cache`).
- Keep state management simple (`setState` or `provider`). Do not add heavy architecture.
- Backend base URL is a single constant. Remember: `localhost` for desktop/web, `10.0.2.2` for the Android emulator, the computer's LAN IP for a real phone.
- Run `dart format .` and `flutter analyze` before committing.
- Do not edit `main.dart` or shared widgets without telling the team, to avoid merge conflicts. Prefer small, frequent commits and `git pull` before starting.

### Localization (no hard-coded UI text)

**Always add a localization string; never hard-code text.** This applies to every change, including quick fixes and prototypes.

- Never put user-visible text directly in widgets. Read it with `AppLocalizations.of(context).someKey` (import `../l10n/app_localizations.dart`).
- "User-visible" means everything: labels, buttons, hints (`hintText`, `labelText`), tooltips, semantics labels (read aloud!), snackbars, error and empty states ("No data"), units with words ("{range} days"), and notes or explanations.
- Every new string goes into **both** `lib/l10n/app_en.arb` (the template) and `lib/l10n/app_pl.arb` **in the same change** as the widget that uses it. Put placeholder/plural metadata (`"@someKey": {...}`) in `app_en.arb`.
- Do not build sentences by joining strings in Dart. Use placeholders (`"areaValue": "{area} ha"`) so each language can order the words itself. Format numbers and dates with `intl` (`NumberFormat`, `DateFormat`) using the current locale.
- The backend sends **codes, not display sentences** (e.g. `productionNoteCode: "all_sweet_lupins"`, `status: "no_data"`). The frontend maps each code to an ARB string; unknown codes show nothing, never the raw code. When the backend adds a code, add it to the mapping and both ARB files. Data values that come with their own languages (crop names as `{"pl": ..., "en": ...}`) are picked by the current language code.
- Before finishing, check for string literals in widgets:
  `grep -rnE "(Text|hintText:|labelText:|tooltip:|label:|semanticLabel:|title:)\s*\(?\s*(const )?['\"]" lib | grep -v app_localizations`
  It must print nothing.
- Code is generated by `flutter gen-l10n` (also runs on `flutter pub get` / `flutter run`). Never edit `app_localizations*.dart` by hand.
- `MaterialApp` uses `AppLocalizations.delegate` plus `GlobalMaterialLocalizations.delegates` **from `material_ui`**. Do not use the generated `AppLocalizations.localizationsDelegates`: it pulls in the deprecated `package:flutter/material` delegates.
- Adding a language: add `lib/l10n/app_<code>.arb`. It is then supported, but only pickable with the flag button once it is added to `switchableLocales` in `lib/l10n/language_options.dart` and given a flag in `language_flag_button.dart` (otherwise the button shows the language code).

### Map overlays ("Conditions" tab)

- Code: `lib/overlays/` (one class per overlay, list in `overlay_registry.dart`, data through
  `MapLayersRepository`), widgets `lib/widgets/overlay_*.dart`, screen `lib/screens/overlays_screen.dart`.
- All overlays read one `GET /api/map-layers` response per place (cached in memory); switching overlays or months
  never sends a new request. Contract: `FieldShift/docs/map-layers.md`; saved real response:
  `assets/mock/map_layers_sample.json` (also the "example data" when the backend is down).
- New monthly backend layer = subclass of `MonthlyLayerOverlay` (layer id, icon, title, legend words) + one line in
  `overlayRegistry` + ARB keys (title and an `overlaySteps…` select message). Legend ranges are computed from the
  backend's thresholds; the Polish legend must equal the backend's labels (a test checks every monthly overlay).
  Other data shapes: subclass `MapOverlay` with its own `parse` (see `SoilQualityOverlay`).
- Heat map: NASA overlays also read `GET /api/map-layers/grid` (5 × 5 NASA POWER cells, ~250 km per block; loaded
  next to the value, the card never waits for it). First the block around the field, then the blocks the map shows
  as the user pans or zooms out (`OverlayController.showArea`, nearest first, 2 at a time); with more than 3 × 3
  blocks on screen the heat map is hidden ("zoom in") and nothing loads. Loaded blocks are merged into one grid
  (`OverlayHeatmap.merge`) so colours blend across block edges; the camera fits only the field's block. `MonthlyLayerOverlay.parseHeatmap` picks the shown
  month; `heatmapPixels` (`lib/models/overlay_heatmap.dart`) blends values between cell centres and colours them with
  the legend's own steps, so every colour on the map is a legend step with words and bars, and the field's cell has
  the card's value. Until it loads, when it fails, and for overlays with `hasHeatmap == false` (soil, erosion: they
  need the field's soil) the value's area is a circle. Saved grid: `assets/mock/map_layers_grid_sample.json`.
- Soil in Poland comes from the parcel details (`/api/parcels/details`, Geoportal): `SoilQualityOverlay.parseParcel`
  shows the soil-agricultural map's complex with soil type, texture and the register's classes, and the map draws
  that map's tiles (`/api/map-tiles/soil-map/…`, from zoom 13). Complexes have no order, so `OverlayLayer.ordered`
  is false (no level bars). Without parcel data (other country, no parcel, source down) it falls back to SoilGrids.
- Plant stress (`PlantStressOverlay`, estimate from dry root zone and hot days) has a heat map like the other
  NASA overlays. Erosion has none: the backend estimates it with the slope of the registered parcel at the point
  (terrain provider, Poland: GUGiK NMT 1 m, cached), falling back to no slope where there is no parcel.
- The map keeps the field in view: the camera goes to the field (heat map: one NASA cell around it), and the round
  button in its bottom corner brings it back. The language flag floats in the top corner of every tab
  (`WithFloatingButton`, `MapButton`), with no bar of its own.
- Values are drawn as areas of their real precision (~1 km soil, ~50 km NASA POWER), never as field-level data.

## Accessibility rules (non-negotiable)

- One question per screen; always a back button and progress indicator.
- Touch targets at least 48 px, preferably larger; text at least 18 px; support system text scaling.
- High contrast. Never rely on colour alone: pair it with an icon and a word.
- Plain language, no jargon ("dry-spell risk", not "precipitation variability"). UI text in Polish and English via localization, not hard-coded in widgets.
- Every external data value shows its source and confidence: measured by satellite / estimated / from your answer.
- Friendly error messages and fallbacks; the app must still work with cached or demo data.

## Data and honesty rules

- NASA data must visibly drive the recommendations (POWER, SMAP, IMERG, MODIS/VIIRS NDVI, SRTM). Non-NASA data (soil, crop traits, parcels) supports it.
- NASA climate grids are coarse; do not claim field-level precision for climate or soil moisture.
- Show uncertainty. Do not invent data; label estimates as estimates.
- Cache external results and ship pre-fetched demo data so the demo never depends on a live API.

## Running locally

Everything in Docker (no local .NET/Flutter needed): `docker compose up --build`: frontend on http://localhost:8080,
backend on http://localhost:5066, database on 5432. Change host ports with `DB_PORT`, `BACKEND_PORT`, `FRONTEND_PORT`
(e.g. `DB_PORT=5433` if the `run.sh` database container is running). The frontend image bakes in the backend URL
(`--dart-define=API_BASE_URL`), so rebuild it after changing `BACKEND_PORT`.

Everything at once: `./run.sh` (database, backend, then the frontend on http://localhost:8080; `./run.sh chrome` or `./run.sh <device-id>` for another device; backend output goes to `backend.log`). The steps it runs:

Database and backend (the frontend falls back to saved data when they are not running):

```fish
docker build -t fieldshift-db db
docker run -d --name fieldshift-db -e POSTGRES_PASSWORD=fieldshift -p 5432:5432 -v fieldshift-db-data:/var/lib/postgresql/data fieldshift-db
cd FieldShift/FieldShift.Web
dotnet run --launch-profile http   # http://localhost:5066, creates the tables on first start
```

The connection string is `ConnectionStrings:Prices` in `appsettings.json`; override it with the `ConnectionStrings__Prices` environment variable. Database tests are skipped unless `FIELDSHIFT_TEST_DB` holds a connection string.

Frontend:

```fish
cd frontend
flutter pub get
flutter run -d chrome            # needs Chromium/Chrome
flutter run -d web-server --web-port 8080   # open http://localhost:8080 in any browser
flutter run                      # pick a connected Android phone
```

Hot reload: `r`. Hot restart: `R`. Quit: `q`. If the build acts strange: `flutter clean && flutter pub get`.

## Definition of done for a change

- Runs on web and (if possible) on a phone.
- `flutter analyze` is clean.
- Works with mock data and with the real backend.
- Follows the accessibility rules above.