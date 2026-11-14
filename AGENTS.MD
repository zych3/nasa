# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo.

## Project

NASA Space Apps hackathon entry for the challenge **"Field Shift: Adapting Farms with NASA Data"**.
We build a decision-support tool that uses NASA Earth observations plus local soil data, crop traits and
farmer priorities to help farmers explore crop-rotation strategies that protect soil and adapt to a changing climate.

**Core principle: the interface must be usable by people who are not comfortable with technology.**
Simple, one question per screen, big touch targets, plain language, read-aloud, no jargon.

## Architecture

```
Flutter app (frontend/)  ->  .NET backend  ->  Decider (scoring)
                                   ^
                                   |
                         Dataflow / data fetching + cache  <-  external data (NASA POWER, soil, parcels...)
```

- **Frontend:** Flutter (Dart), in `frontend/`. Targets: web, Android (Linux desktop only for local dev).
- **Backend:** .NET. Owns data fetching, caching, scoring and the API contract.
- **Database:** PostgreSQL (`db/Dockerfile`), used as the crop price cache through EF Core (`PricesDbContext`). Price endpoints answer from the database; the source API (GUS) is only called when the stored prices are stale (`Prices:StaleAfterHours`, default 24). If GUS is down, the stored prices are served. The schema is the EF migrations in `FieldShift/FieldShift.Web/Migrations`; the backend applies them itself. Change the schema only by editing the entities and running `dotnet ef migrations add <Name>`, never by hand in SQL.
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
| Parcel details (polygon, public data, soil, terrain) | `GET /api/parcels/{id}` |
| Risk indicators with source and confidence | `GET /api/parcels/{id}/indicators` |
| Map colouring (best crop per parcel) | `POST /api/parcels/suitability` |
| Ranked rotation plans for one parcel | `POST /api/recommendations` |
| Crop catalogue (names, photo, area/yield, growing needs) | `GET /api/crops`, `GET /api/crops/{id}` |
| Latest real prices of one crop (default 10, max 240; `status: "no_data"` when none; 503 when the database is down) | `GET /api/crops/{id}/prices?count=10` |
| Trends: recommended / profitable crops nearby | `GET /api/trends?parcelId=...` |

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
- Keep state management simple (`setState` or `provider`). Do not add heavy architecture.
- Backend base URL is a single constant. Remember: `localhost` for desktop/web, `10.0.2.2` for the Android emulator, the computer's LAN IP for a real phone.
- Run `dart format .` and `flutter analyze` before committing.
- Do not edit `main.dart` or shared widgets without telling the team, to avoid merge conflicts. Prefer small, frequent commits and `git pull` before starting.

### Localization (no hard-coded UI text)

**Always add a localization string; never hard-code text.** This applies to every change, including quick fixes and prototypes.

- Never put user-visible text directly in widgets. Read it with `AppLocalizations.of(context).someKey` (import `../l10n/app_localizations.dart`).
- "User-visible" means everything: labels, buttons, hints (`hintText`, `labelText`), tooltips, semantics labels (read aloud!), snackbars, error and empty states ("No data"), units with words ("{range} days"), and notes or explanations.
- Every new string goes into **both** `lib/l10n/app_en.arb` (the template) and `lib/l10n/app_pl.arb` **in the same change** as the widget that uses it. Put placeholder/plural metadata (`"@someKey": {...}`) in `app_en.arb`.
- Do not build sentences by joining strings in Dart. Use placeholders (`"priceNow": "{price} {currency} per {unit}"`) so each language can order the words itself. Format numbers and dates with `intl` (`NumberFormat`, `DateFormat`) using the current locale.
- The backend sends **codes, not display sentences** (e.g. `noteCode: "one_price_all_barley"`, `status: "no_data"`). The frontend maps each code to an ARB string (see `lib/l10n/crop_note_text.dart`); unknown codes show nothing, never the raw code. When the backend adds a code, add it to the mapping and both ARB files. Data values that come with their own languages (crop names as `{"pl": ..., "en": ...}`) are picked by the current language code.
- Before finishing, check for string literals in widgets:
  `grep -rnE "(Text|hintText:|labelText:|tooltip:|label:|semanticLabel:|title:)\s*\(?\s*(const )?['\"]" lib | grep -v app_localizations`
  It must print nothing.
- Code is generated by `flutter gen-l10n` (also runs on `flutter pub get` / `flutter run`). Never edit `app_localizations*.dart` by hand.
- `MaterialApp` uses `AppLocalizations.delegate` plus `GlobalMaterialLocalizations.delegates` **from `material_ui`**. Do not use the generated `AppLocalizations.localizationsDelegates`: it pulls in the deprecated `package:flutter/material` delegates.
- Adding a language: add `lib/l10n/app_<code>.arb`. It is then supported, but only pickable with the flag button once it is added to `switchableLocales` in `lib/l10n/language_options.dart` and given a flag in `language_flag_button.dart` (otherwise the button shows the language code).

## Accessibility rules (non-negotiable)

- One question per screen; always a back button and progress indicator.
- Touch targets at least 48 px, preferably larger; text at least 18 px; support system text scaling.
- High contrast. Never rely on colour alone: pair it with an icon and a word.
- Every screen has a read-aloud button (`flutter_tts`).
- Plain language, no jargon ("dry-spell risk", not "precipitation variability"). UI text in Polish and English via localization, not hard-coded in widgets.
- Every external data value shows its source and confidence: measured by satellite / estimated / from your answer.
- Friendly error messages and fallbacks; the app must still work with cached or demo data.

## Data and honesty rules

- NASA data must visibly drive the recommendations (POWER, SMAP, IMERG, MODIS/VIIRS NDVI, SRTM). Non-NASA data (soil, crop traits, parcels) supports it.
- NASA climate grids are coarse; do not claim field-level precision for climate or soil moisture.
- Show uncertainty. Do not invent data; label estimates as estimates.
- Cache external results and ship pre-fetched demo data so the demo never depends on a live API.

## Running locally

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