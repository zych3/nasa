using FieldShift.Web.FieldData.Cache;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FieldShift.Web.FieldData;

public static class FieldDataRegistration
{
    /// <summary>
    /// The field data cache (PostgreSQL, <c>ConnectionStrings:FieldData</c>, falling back to the prices database)
    /// and <see cref="ParcelDetailsService"/>. Providers are registered by the parts that own them: SoilGrids by
    /// <c>AddFieldProfile</c>, national ones by their country (<c>AddPoland</c>).
    /// </summary>
    public static void AddFieldData(this WebApplicationBuilder builder)
    {
        var connectionString = builder.Configuration.GetConnectionString("FieldData")
            ?? builder.Configuration.GetConnectionString("Prices")
            ?? throw new InvalidOperationException("Missing configuration: ConnectionStrings:FieldData");

        // A cache must not slow requests down when the database is away: give up connecting after 5 s.
        var npgsql = new NpgsqlConnectionStringBuilder(connectionString);
        npgsql.Timeout = Math.Min(npgsql.Timeout, 5);

        builder.Services.AddDbContextFactory<FieldDataDbContext>(o => o.UseNpgsql(
            npgsql.ConnectionString,
            x => x.MigrationsHistoryTable(FieldDataDbContext.MigrationsHistoryTable)));
        builder.Services.AddSingleton<FieldDataSchema>();
        builder.Services.AddSingleton<IProviderCache, PostgresProviderCache>();
        builder.Services.AddSingleton<FieldDataCache>();
        builder.Services.AddScoped<ParcelDetailsService>();
    }
}
