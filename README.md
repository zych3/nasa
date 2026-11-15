# FieldShift

FieldShift suggests a multi-year crop rotation for a farmer's field, using NASA climate data and soil data. It simulates how each crop changes the soil for the next one, and it judges every plan by the worst weather years. The focus is ecology: building soil carbon, keeping the soil covered with catch crops, looking after nitrogen and holding back disease and water stress, with yield stability as one goal among them. Every suggestion comes with reasons, so the farmer can see why a plan was proposed and decide for themselves.

Built for the NASA Space Apps hackathon, challenge **"Field Shift: Adapting Farms with NASA Data"**. You point at your field, say what grew there and what matters to you (healthy soil, a safe harvest, something in between), and the app suggests what to sow in the coming years. It also tells you **why**. No black box. The rules are deterministic.

The whole interface is made for people who are not comfortable with technology: one question per screen, big buttons, plain language. Available in Polish and English.

## Quick start

The whole thing (database, backend and app) starts with one command, all you need is Docker:

```bash
docker compose up --build
```

When the build is done, the app waits at http://localhost:8080. More on running it below.

## Where the data comes from

- **NASA POWER**: temperature and rainfall from the last years. The whole recommendation stands on it.
- **NASA SMAP, IMERG, MODIS**: soil moisture, rain, vegetation, surface temperature. These need an Earthdata token (see below). Without it those parts are simply left out of the satellite card and everything else works as usual.
- **SoilGrids (ISRIC)**: modelled soil for any point in the world.
- **Polish registers** (Geoportal, EGiB, GUGiK, ULDK): parcels, soil classes, terrain slope.

The rule is simple: we don't pretend to know more than we do. The NASA grid is tens of kilometres wide, so we don't promise accuracy down to the metre. Every value shows where it comes from and how much to trust it.

## What's inside

```
frontend/   Flutter app (web and Android)
FieldShift/
  FieldShift.Web/          .NET backend: API, data fetching and cache, accounts
  FieldShift.Prediction/   recommendation engine (season simulation and rotation search)
  *.Tests/                 tests
db/         PostgreSQL (data cache, accounts, saved plans)
```

The frontend only talks to our backend. It never goes to NASA or anywhere else on its own, that's what the backend is for.

## How the engine works

`FieldShift.Prediction` is plain, deterministic code: the same input always gives the same output, and no crop-specific knowledge lives in it. All agronomy (crops, soil and disease variables, strategies, settings) is JSON in `FieldShift/FieldShift.Prediction/Data/`, and every number there carries a `source` and a `confidence`. Most values are expert estimates, and the app says so.

```csharp
var loaded = KnowledgeBaseLoader.Load("Data");
var result = RecommendationService.Recommend(plot, loaded.KnowledgeBase!, loaded.Settings!);
```

`result` holds, per strategy, the best plan plus alternatives with reasons, why each crop was or was not a candidate, and warnings about data gaps (no snow data, estimated ET0, no history).

**Steps**

1. **Validate** the knowledge base. Anything missing or inconsistent fails here; there are no hidden defaults.
2. **Describe the plot**: soil texture, pH, organic carbon, water capacity.
3. **Screen the crops.** For every crop and every climate year, a survival score from soil texture, heat at flowering, winterkill and a daily water balance. A crop is judged by the mean of its worst 20 % of years, and dropped if that falls below the strategy's floor. With `survival.recencyHalfLifeYears` (shipped: 6) newer years weigh more. That is only less reliance on old weather, not a climate forecast.
4. **Replay the farmer's past crops** to get the starting soil.
5. **Search rotations** (3–5 years, repeated four times so slow effects such as disease build-up show before a plan is scored), prune them with hard rules and rank them per strategy.
6. **Try catch crops and field actions** on the chosen plans.
7. **Explain**: every season gets ranked reasons.

**One season.** The soil is a set of variables: stocks that persist (humus, pH, compaction), a pool that is used up (mineral nitrogen), pressures that decay unless a host crop reloads them (pathogens, pests, weeds) and events that last one season (winter cover). A season checks the crop against the inherited soil, applies what the crop, the catch crop and the actions leave behind, then decays the pressures, applies links such as acidification → pH and keeps every value in its range.

**Scoring.** Seven objectives: harvest (survival × yield), humus, disease pressure, nitrogen, winter cover, soil structure and water stress. There is no price data, so gross margin is not scored. A strategy (`soilHealth`, `survival`, `balanced`) weighs them, either as a weighted sum or as the point closest to the ideal on the Pareto front. Hard rules prune the search: sowing and harvest timing, years before a crop may return, years in a row, the farmer's exclusions, group limits (at most 67 % cereals) and the survival floor. Each broken rule has a stable reason code. Alternatives must differ in their crops.

**Interaction rules.** `Data/stateInteractions.json` holds hand-written rules of the form "when A is high, effect or response B is stronger (or weaker)", for example plenty of mineral nitrogen left makes eyespot build up faster in cereals. The trigger is a state variable at the start of the season, the factor is `1 + (multiplier − 1) × trigger`, and several rules on one target multiply up to a cap. A rule that fires shows up as a reason (`interaction.rule.<id>`), and the validator rejects unknown variables and bad multipliers. The shipped rules are expert estimates and need agronomic review.

**Settings** live in `Data/engineSettings.json` (calendar, survival, objectives, search size, soil constants) and are validated at startup.

**Adding a crop needs no code.** Add an entry to `Data/crops.json` or a file in `Data/crops/`: `id`, `type` (`winter`, `spring`, `perennial`, `catch`), `tags`, sowing and harvest windows (day of year), suitability ranges, water profile, `responses` (curves from state variables to a 0–1 multiplier), `effects` (what it leaves behind), hard rules, and a `source` plus `confidence` for every number. A new state variable goes into `stateVars.json`. The validator names anything missing, and an architecture test fails if a crop name appears in the engine's code.

**Known limits**

- Agronomic values are mostly expert estimates and need review by agronomists.
- Climate is a sample of past years (about 12, from NASA POWER, 2014 onwards). There is no trend, projection or climate-change scenario.
- Four unrolled cycles are a close approximation of steady state, not a proof.
- With a crop history, transitions are limited to short bridges to keep the search fast.
- `PreferredCrops` and `Priorities` of the engine's input are not used yet.
- `FieldShift/FieldShift.Prediction/samples/plot-52.2-21.48.json` has real soil values but synthetic weather. Don't present its results as findings.

## Running it

### Everything in Docker (easiest)

No .NET or Flutter needed on your machine:

```bash
docker compose up --build
```

- app: http://localhost:8080
- backend: http://localhost:5066
- database: localhost:5432

Change the ports with `DB_PORT`, `BACKEND_PORT` and `FRONTEND_PORT`. Heads up: the backend address is baked into the frontend image, so after changing `BACKEND_PORT` you have to build the frontend again.

### The hands-on way, without Docker for everything

```bash
./run.sh            # database, backend and frontend at http://localhost:8080
./run.sh chrome     # or on another device: ./run.sh <device-id>
```

Backend logs go to `backend.log`. If you'd rather do it by hand:

```bash
# database
docker build -t fieldshift-db db
docker run -d --name fieldshift-db -e POSTGRES_PASSWORD=fieldshift -p 5432:5432 \
  -v fieldshift-db-data:/var/lib/postgresql/data fieldshift-db

# backend (needs .NET SDK 10)
cd FieldShift/FieldShift.Web
dotnet run --launch-profile http     # http://localhost:5066

# frontend (needs Flutter)
cd frontend
flutter pub get
flutter run -d chrome
```

The backend creates the database tables itself on start. When there is no database or backend, the app falls back to saved demo data, so a demo never ends with an empty screen.

### NASA Earthdata token (optional)

Rain (IMERG) and soil moisture (SMAP) need an Earthdata user token. Put it in the `.env` file (it's git-ignored) as `EARTHDATA_TOKEN`, and with `dotnet run` use `dotnet user-secrets set "Earthdata:Token" ...`. The token expires after 60 days, so if the tiles suddenly go quiet, that's probably why. Never commit it.

### Test account

Locally (Docker and Development mode) there is a login button for a shared `test` account, no password. It doesn't exist in production.

## Tests

```bash
cd FieldShift && dotnet test      # backend and engine
cd frontend && flutter test       # frontend
```

Some backend tests call the real GUGiK services, so without internet they will fall over. Database tests are skipped until you set `FIELDSHIFT_TEST_DB` to a test database connection string.

## For those who want to dig into the code

- [`AGENTS.MD`](AGENTS.MD): project rules, endpoint list, Flutter conventions, translations. Read it before your first commit.
- [How the engine works](#how-the-engine-works), and its data in [`FieldShift/FieldShift.Prediction/Data/`](FieldShift/FieldShift.Prediction/Data).
- [`FieldShift/docs/`](FieldShift/docs): descriptions of the map layers and parcel data.

A few things we will nag you about in code review: no text hard-coded in widgets (everything goes through the `.arb` files), `flutter analyze` must be clean, and the database schema changes only through EF migrations, never by hand in SQL.

## Known pain points

The first plan for a new place can take a while, because we wait for external servers, and SoilGrids is sometimes just slow. Later requests for the same area are fast, because the results land in the cache. Only a limitation when running locally.
