#!/usr/bin/env bash
# Start the whole FieldShift stack: PostgreSQL (Docker), .NET backend, Flutter frontend.
#
# Usage (from anywhere):
#   ./run.sh                 # frontend on http://localhost:8080 (web-server)
#   ./run.sh chrome          # frontend in Chrome
#   ./run.sh <device-id>     # any `flutter devices` id, e.g. an Android phone
#
# Quit the frontend with `q` or Ctrl+C; the backend is stopped too.
# The database container keeps running (stop it with `docker stop fieldshift-db`).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="${1:-web-server}"
DB_NAME=fieldshift-db
BACKEND_URL=http://localhost:5066
BACKEND_LOG="$ROOT/backend.log"
BACKEND_PID=""

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() {
    if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        log "Stopping backend"
        kill "$BACKEND_PID" 2>/dev/null || true
        wait "$BACKEND_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

for cmd in docker dotnet flutter curl; do
    command -v "$cmd" >/dev/null || die "'$cmd' is not installed or not on PATH"
done

# --- Database -----------------------------------------------------------------
if ! docker image inspect "$DB_NAME" >/dev/null 2>&1; then
    log "Building database image"
    docker build -t "$DB_NAME" "$ROOT/db"
fi

if docker container inspect "$DB_NAME" >/dev/null 2>&1; then
    if [[ "$(docker inspect -f '{{.State.Running}}' "$DB_NAME")" != "true" ]]; then
        log "Starting database container"
        docker start "$DB_NAME" >/dev/null
    else
        log "Database container already running"
    fi
else
    log "Creating database container"
    docker run -d --name "$DB_NAME" \
        -e POSTGRES_PASSWORD=fieldshift \
        -p 5432:5432 \
        -v fieldshift-db-data:/var/lib/postgresql/data \
        "$DB_NAME" >/dev/null
fi

log "Waiting for database"
for _ in $(seq 1 60); do
    docker exec "$DB_NAME" pg_isready -U fieldshift -d fieldshift >/dev/null 2>&1 && break
    sleep 1
done
docker exec "$DB_NAME" pg_isready -U fieldshift -d fieldshift >/dev/null 2>&1 \
    || die "Database did not become ready (docker logs $DB_NAME)"

# --- Backend ------------------------------------------------------------------
if curl -s -o /dev/null "$BACKEND_URL/" >/dev/null 2>&1; then
    log "Backend already running at $BACKEND_URL, reusing it"
else
    log "Starting backend (log: $BACKEND_LOG)"
    (cd "$ROOT/FieldShift/FieldShift.Web" && exec dotnet run --launch-profile http) >"$BACKEND_LOG" 2>&1 &
    BACKEND_PID=$!

    log "Waiting for backend at $BACKEND_URL"
    for _ in $(seq 1 120); do
        curl -s -o /dev/null "$BACKEND_URL/" >/dev/null 2>&1 && break
        kill -0 "$BACKEND_PID" 2>/dev/null || { tail -n 30 "$BACKEND_LOG" >&2; die "Backend exited, see $BACKEND_LOG"; }
        sleep 1
    done
    curl -s -o /dev/null "$BACKEND_URL/" >/dev/null 2>&1 || die "Backend did not answer in time, see $BACKEND_LOG"
fi
log "Backend is up"

# --- Frontend -----------------------------------------------------------------
cd "$ROOT/frontend"
log "flutter pub get"
flutter pub get

if [[ "$DEVICE" == "web-server" ]]; then
    log "Frontend: open http://localhost:8080 once it is built"
    flutter run -d web-server --web-port 8080
else
    flutter run -d "$DEVICE"
fi
