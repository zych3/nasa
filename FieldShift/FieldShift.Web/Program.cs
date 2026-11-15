using FieldShift.Web.Accounts;
using FieldShift.Web.ClimateTrends;
using FieldShift.Web.Countries;
using FieldShift.Web.Countries.Poland;
using FieldShift.Web.Data;
using FieldShift.Web.FieldData;
using FieldShift.Web.FieldProfile;
using FieldShift.Web.MapLayers;
using FieldShift.Web.Recommendations;
using FieldShift.Web.Satellite;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;
using FieldShift.Web.Weather;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<ICropRepository, InMemoryCropRepository>();

// Prices are cached in PostgreSQL through EF Core (schema: Migrations/). The source API is only called
// when they are stale.
var pricesDb = builder.Configuration.GetConnectionString("Prices")
    ?? throw new InvalidOperationException("Missing configuration: ConnectionStrings:Prices");
builder.Services.AddDbContext<PricesDbContext>(o => o.UseNpgsql(pricesDb));
builder.Services.AddSingleton<PricesSchema>();
builder.Services.AddScoped<IPriceHistoryRepository, EfPriceHistoryRepository>();
builder.Services.Configure<PriceCacheOptions>(builder.Configuration.GetSection("Prices"));
builder.Services.AddSingleton<PriceSyncGate>();
builder.Services.AddScoped<CropPriceService>();

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.AddPoland();
builder.AddFieldProfile();
builder.AddMapLayers();
builder.AddFieldData();
builder.AddRecommendations();
builder.AddAccounts();
builder.AddClimateTrends();
builder.AddSatellite();

builder.Services.AddHttpClient<FrostRiskService>(c =>
        c.BaseAddress = new Uri(builder.Configuration["Weather:OpenMeteoBaseUrl"] ?? "https://api.open-meteo.com/"))
    .AddStandardResilienceHandler();

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .SetIsOriginAllowed(origin => new Uri(origin).IsLoopback)
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

app.UseResponseCompression();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseCors();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();