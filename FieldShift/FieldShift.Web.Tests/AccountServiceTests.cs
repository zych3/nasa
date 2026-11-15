using FieldShift.Web.Accounts;

namespace TestProject1;

public sealed class AccountServiceTests
{
    [Theory]
    [InlineData(" Jan@Example.COM ", "jan@example.com")]
    [InlineData("a@b", "a@b")]
    public void NormalizesEmail(string input, string expected) =>
        Assert.Equal(expected, AccountService.NormalizeEmail(input));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("no-at-sign")]
    [InlineData("@example.com")]
    [InlineData("jan@")]
    [InlineData("jan@@example.com")]
    [InlineData("jan kowalski@example.com")]
    public void RejectsInvalidEmail(string? input) =>
        Assert.Null(AccountService.NormalizeEmail(input));

    [Fact]
    public void HashesTokenToSha256Hex()
    {
        var hash = AccountService.HashToken("abc");
        Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash);
        Assert.Equal(64, hash.Length);
    }
}
