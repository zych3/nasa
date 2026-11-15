using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;

namespace FieldShift.Web.Accounts;

public static class AccountsRegistration
{
    /// <summary>
    /// Users and sessions (PostgreSQL, <c>ConnectionStrings:Accounts</c>, falling back to the prices database),
    /// <see cref="AccountService"/> and bearer token authentication.
    /// </summary>
    public static void AddAccounts(this WebApplicationBuilder builder)
    {
        var connectionString = builder.Configuration.GetConnectionString("Accounts")
            ?? builder.Configuration.GetConnectionString("Prices")
            ?? throw new InvalidOperationException("Missing configuration: ConnectionStrings:Accounts");

        builder.Services.AddDbContextFactory<AccountsDbContext>(o => o.UseNpgsql(
            connectionString,
            x => x.MigrationsHistoryTable(AccountsDbContext.MigrationsHistoryTable)));
        builder.Services.AddSingleton<AccountsSchema>();
        builder.Services.Configure<AccountOptions>(builder.Configuration.GetSection("Accounts"));
        builder.Services.AddSingleton<AccountService>();

        builder.Services
            .AddAuthentication(TokenAuthenticationHandler.SchemeName)
            .AddScheme<AuthenticationSchemeOptions, TokenAuthenticationHandler>(TokenAuthenticationHandler.SchemeName, null);
        builder.Services.AddAuthorization();
    }
}