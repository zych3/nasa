# .NET backend (FieldShift.Web).
#
# Build (from the repo root):
#   docker build -t fieldshift-backend FieldShift
#
# Listens on port 8080 inside the container. Set the database with the
# ConnectionStrings__Prices environment variable (see docker-compose.yml).

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY FieldShift.Prediction/FieldShift.Prediction.csproj FieldShift.Prediction/
COPY FieldShift.Web/FieldShift.Web.csproj FieldShift.Web/
RUN dotnet restore FieldShift.Web/FieldShift.Web.csproj
COPY FieldShift.Prediction/ FieldShift.Prediction/
COPY FieldShift.Web/ FieldShift.Web/
RUN dotnet publish FieldShift.Web/FieldShift.Web.csproj -c Release -o /out --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out .
# The backend refreshes Data/crop-data.json at runtime, so the app user must be able to write there.
RUN chown -R $APP_UID /app/Data
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "FieldShift.Web.dll"]
