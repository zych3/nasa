using FieldShift.Web.Accounts;
using Microsoft.EntityFrameworkCore;

namespace TestProject1;

public sealed class AccountServiceTests : IAsyncLifetime
{
    private readonly string _email = $"test-{Guid.NewGuid():N}@example.com";

    private sealed class Factory(DbContextOptions<AccountsDbContext> options) : IDbContextFactory<AccountsDbContext>
    {
        public AccountsDbContext CreateDbContext() => new(options);
    }

    private IDbContextFactory<AccountsDbContext>? _contexts;

    public Task InitializeAsync()
    {
        var connectionString = Environment.GetEnvironmentVariable(PostgresFactAttribute.Variable);
        if (!string.IsNullOrWhiteSpace(connectionString))
        {
            _contexts = new Factory(new DbContextOptionsBuilder<AccountsDbContext>()
                .UseNpgsql(connectionString, x => x.MigrationsHistoryTable(AccountsDbContext.MigrationsHistoryTable))
                .Options);
        }

        return Task.CompletedTask;
    }

    public async Task DisposeAsync()
    {
        if (_contexts is null)
        {
            return;
        }

        await new AccountsSchema(_contexts).EnsureAppliedAsync(CancellationToken.None);
        await using var db = await _contexts.CreateDbContextAsync();
        await db.Users.Where(u => u.Email == _email).ExecuteDeleteAsync();
    }

    private AccountService Service() => new(_contexts!, new AccountsSchema(_contexts!), TimeProvider.System);

    [Theory]
    [InlineData("  Jan.Kowalski@Example.COM ", "jan.kowalski@example.com")]
    [InlineData("rolnik@wp.pl", "rolnik@wp.pl")]
    [InlineData("no-at-sign.pl", null)]
    [InlineData("a@localhost", null)]
    [InlineData("Jan <jan@example.com>", null)]
    [InlineData("", null)]
    [InlineData(null, null)]
    public void Normalizes_or_rejects_emails(string? input, string? expected)
    {
        Assert.Equal(expected, AccountService.NormalizeEmail(input));
    }

    [Fact]
    public void Token_hash_is_stable_and_not_the_token()
    {
        var hash = AccountService.HashToken("abc");

        Assert.Equal(hash, AccountService.HashToken("abc"));
        Assert.NotEqual("abc", hash);
        Assert.Equal(64, hash.Length);
    }

    [Fact]
    public async Task Rejects_bad_input_before_touching_the_database()
    {
        // No database: these must answer from validation alone.
        var service = new AccountService(null!, null!, TimeProvider.System);

        Assert.Equal(AccountErrorCodes.InvalidEmail,
            (await service.RegisterAsync("nope", "longenough", null, CancellationToken.None)).ErrorCode);
        Assert.Equal(AccountErrorCodes.PasswordTooShort,
            (await service.RegisterAsync("a@b.pl", "short", null, CancellationToken.None)).ErrorCode);
        Assert.Equal(AccountErrorCodes.InvalidCredentials,
            (await service.LoginAsync("nope", "whatever", CancellationToken.None)).ErrorCode);
    }

    [PostgresFact]
    public async Task Register_login_me_logout()
    {
        var service = Service();
        var ct = CancellationToken.None;

        var registered = await service.RegisterAsync(_email, "tajne-haslo", " Jan ", ct);
        Assert.NotNull(registered.Session);
        Assert.Equal("Jan", registered.Session!.User.Name);

        Assert.Equal(AccountErrorCodes.EmailTaken,
            (await service.RegisterAsync(_email.ToUpperInvariant(), "inne-haslo", null, ct)).ErrorCode);
        Assert.Equal(AccountErrorCodes.InvalidCredentials,
            (await service.LoginAsync(_email, "zle-haslo", ct)).ErrorCode);

        var login = await service.LoginAsync(_email, "tajne-haslo", ct);
        Assert.NotNull(login.Session);
        Assert.NotEqual(registered.Session.Token, login.Session!.Token);

        var me = await service.GetUserAsync(login.Session.Token, ct);
        Assert.Equal(_email, me?.Email);

        await service.LogoutAsync(login.Session.Token, ct);
        Assert.Null(await service.GetUserAsync(login.Session.Token, ct));
        Assert.NotNull(await service.GetUserAsync(registered.Session.Token, ct));
    }
}
