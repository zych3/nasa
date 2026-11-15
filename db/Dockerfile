# PostgreSQL for the FieldShift backend (accounts, field data cache).
#
# The image only creates the database and its user. The tables are created by the backend:
# it applies its EF Core migrations (FieldShift/FieldShift.Web/Migrations) when it starts.
#
# Build (from the repo root):
#   docker build -t fieldshift-db db
#
# Run (the password is set here, not baked into the image):
#   docker run -d --name fieldshift-db \
#     -e POSTGRES_PASSWORD=fieldshift \
#     -p 5432:5432 \
#     -v fieldshift-db-data:/var/lib/postgresql/data \
#     fieldshift-db
#
# The backend connects with ConnectionStrings:Prices from appsettings.json
# (override with the ConnectionStrings__Prices environment variable).

FROM postgres:17-alpine

ENV POSTGRES_DB=fieldshift \
    POSTGRES_USER=fieldshift

EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1
