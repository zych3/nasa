using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FieldShift.Web.Accounts;

public static class AccountsRegistration
{
    /// <summary>
    /// User accounts (PostgreSQL, <c>ConnectionStrings:Accounts</c>, falling back to the prices database).
    /// </summary>
    public static void AddAccounts(this WebApplicationBuilder builder)
    {
        var connectionString = builder.Configuration.GetConnectionString("Accounts")
            ?? builder.Configuration.GetConnectionString("Prices")
            ?? throw new InvalidOperationException("Missing configuration: ConnectionStrings:Accounts");

        // Signing in must not hang when the database is away: give up connecting after 5 s.
        var npgsql = new NpgsqlConnectionStringBuilder(connectionString);
        npgsql.Timeout = Math.Min(npgsql.Timeout, 5);

        builder.Services.AddDbContextFactory<AccountsDbContext>(o => o.UseNpgsql(
            npgsql.ConnectionString,
            x => x.MigrationsHistoryTable(AccountsDbContext.MigrationsHistoryTable)));
        builder.Services.AddSingleton<AccountsSchema>();
        builder.Services.AddSingleton<AccountService>();
    }
}
