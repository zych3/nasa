using FieldShift.Web.Countries;
using FieldShift.Web.Countries.Poland;
using FieldShift.Web.Options;
using FieldShift.Web.Repositories;
using FieldShift.Web.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<ICropRepository, InMemoryCropRepository>();
builder.Services.AddSingleton<IPriceHistoryRepository, InMemoryPriceHistoryRepository>();
builder.Services.AddScoped<CropPriceService>();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var appOptions = AppOptions.Load(builder.Configuration);
builder.Services.AddSingleton(appOptions);

builder.AddPoland(appOptions.Poland);

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .SetIsOriginAllowed(origin => new Uri(origin).IsLoopback)
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseCors();

app.UseAuthorization();

app.MapControllers();

app.Run();