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
- **NASA SMAP, IMERG, MODIS**: soil moisture, rain, vegetation, surface temperature. These need an Earthdata token (see below). Without it those tiles say "not configured" and everything else works as usual.
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
- [`FieldShift/FieldShift.Prediction/docs/engine.md`](FieldShift/FieldShift.Prediction/docs/engine.md): how the recommendation engine works.
- [`FieldShift/docs/`](FieldShift/docs): descriptions of the map layers and parcel data.

A few things we will nag you about in code review: no text hard-coded in widgets (everything goes through the `.arb` files), `flutter analyze` must be clean, and the database schema changes only through EF migrations, never by hand in SQL.

## Known pain points

The first plan for a new place can take a while, because we wait for external servers, and SoilGrids is sometimes just slow. Later requests for the same area are fast, because the results land in the cache. Only a limitation when running locally.
