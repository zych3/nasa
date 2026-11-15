using FieldShift.Web.Accounts;

namespace TestProject1;

public sealed class AccountServiceTests
{
    [Theory]
    [InlineData(" JanKowalski ", "jankowalski")]
    [InlineData("jan.k_1-2", "jan.k_1-2")]
    [InlineData("Łukasz", "łukasz")]
    [InlineData("abc", "abc")]
    public void NormalizesUsername(string input, string expected) =>
        Assert.Equal(expected, AccountService.NormalizeUsername(input));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("ab")]
    [InlineData("jan kowalski")]
    [InlineData("jan@poczta.pl")]
    [InlineData("123456789012345678901234567890123")]
    public void RejectsInvalidUsername(string? input) =>
        Assert.Null(AccountService.NormalizeUsername(input));

    [Fact]
    public void HashesTokenToSha256Hex()
    {
        var hash = AccountService.HashToken("abc");
        Assert.Equal("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hash);
        Assert.Equal(64, hash.Length);
    }
}