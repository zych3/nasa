using System.Text.Json;
using FieldShift.Web.Accounts;
using FieldShift.Web.DTOs;

namespace TestProject1;

public sealed class SavedParcelRulesTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 15, 12, 0, 0, TimeSpan.Zero);

    private static JsonElement Json(string json) => JsonDocument.Parse(json).RootElement.Clone();

    private static SyncParcelItem Item(string id, DateTimeOffset at, bool deleted = false) => new()
    {
        ParcelId = id,
        UpdatedAt = at,
        Deleted = deleted,
        Parcel = deleted ? null : Json($$"""{"id":"{{id}}","lat":52.4,"lon":21.1}"""),
    };

    private static SavedParcel Stored(DateTimeOffset at, bool deleted = false) => new()
    {
        UserId = Guid.NewGuid(),
        ParcelId = "p1",
        DataJson = """{"id":"p1","address":"old"}""",
        UpdatedAt = at,
        IsDeleted = deleted,
    };

    [Fact]
    public void AValidRequestHasNoError() =>
        Assert.Null(SavedParcelRules.Validate(new SyncParcelsRequest { Items = [Item("p1", Now), Item("p2", Now, true)] }));

    [Fact]
    public void ANewDeviceMaySendNothing()
    {
        Assert.Null(SavedParcelRules.Validate(new SyncParcelsRequest()));
        Assert.Null(SavedParcelRules.Validate(new SyncParcelsRequest { Items = [] }));
    }

    [Fact]
    public void RejectsAMissingIdTimeOrParcel()
    {
        Assert.Equal(SavedParcelErrorCodes.InvalidParcels,
            SavedParcelRules.Validate(new SyncParcelsRequest { Items = [Item(" ", Now)] }));
        Assert.Equal(SavedParcelErrorCodes.InvalidParcels,
            SavedParcelRules.Validate(new SyncParcelsRequest { Items = [Item("p1", Now) with { UpdatedAt = null }] }));
        Assert.Equal(SavedParcelErrorCodes.InvalidParcels,
            SavedParcelRules.Validate(new SyncParcelsRequest { Items = [Item("p1", Now) with { Parcel = null }] }));
        Assert.Equal(SavedParcelErrorCodes.InvalidParcels,
            SavedParcelRules.Validate(new SyncParcelsRequest { Items = [Item("p1", Now) with { Parcel = Json("[1]") }] }));
    }

    [Fact]
    public void RejectsTheSameParcelTwice() =>
        Assert.Equal(SavedParcelErrorCodes.InvalidParcels,
            SavedParcelRules.Validate(new SyncParcelsRequest { Items = [Item("p1", Now), Item("p1", Now)] }));

    [Fact]
    public void RejectsMoreThanTheLimit()
    {
        var items = Enumerable.Range(0, SavedParcelRules.MaxParcelsPerUser + 1).Select(i => Item($"p{i}", Now)).ToList();
        Assert.Equal(SavedParcelErrorCodes.TooManyParcels, SavedParcelRules.Validate(new SyncParcelsRequest { Items = items }));
    }

    [Fact]
    public void RemovalsDoNotCountTowardsTheLimit()
    {
        var items = Enumerable.Range(0, SavedParcelRules.MaxParcelsPerUser).Select(i => Item($"p{i}", Now)).ToList();
        items.Add(Item("gone", Now, deleted: true));
        Assert.Null(SavedParcelRules.Validate(new SyncParcelsRequest { Items = items }));
    }

    [Fact]
    public void ANewerChangeReplacesTheStoredParcel()
    {
        var stored = Stored(Now.AddHours(-1));

        Assert.True(SavedParcelRules.Apply(stored, Item("p1", Now), Now));

        Assert.Equal(Now, stored.UpdatedAt);
        Assert.Contains("52.4", stored.DataJson);
    }

    [Fact]
    public void AnOlderChangeIsIgnored()
    {
        var stored = Stored(Now);

        Assert.False(SavedParcelRules.Apply(stored, Item("p1", Now.AddHours(-1)), Now));

        Assert.Equal(Now, stored.UpdatedAt);
        Assert.Contains("old", stored.DataJson);
    }

    [Fact]
    public void ATieKeepsTheStoredParcel() =>
        Assert.False(SavedParcelRules.Apply(Stored(Now), Item("p1", Now), Now));

    [Fact]
    public void ANewerRemovalMarksItRemoved()
    {
        var stored = Stored(Now.AddHours(-1));

        Assert.True(SavedParcelRules.Apply(stored, Item("p1", Now, deleted: true), Now));

        Assert.True(stored.IsDeleted);
    }

    [Fact]
    public void ANewerAddAfterARemovalBringsItBack()
    {
        var stored = Stored(Now.AddHours(-1), deleted: true);

        Assert.True(SavedParcelRules.Apply(stored, Item("p1", Now), Now));

        Assert.False(stored.IsDeleted);
        Assert.Contains("52.4", stored.DataJson);
    }

    [Fact]
    public void AnOlderAddCannotUndoANewerRemoval()
    {
        var stored = Stored(Now, deleted: true);

        Assert.False(SavedParcelRules.Apply(stored, Item("p1", Now.AddDays(-1)), Now));

        Assert.True(stored.IsDeleted);
    }

    [Fact]
    public void ATimeInTheFutureCountsAsNow()
    {
        var stored = Stored(Now.AddHours(-1));

        Assert.True(SavedParcelRules.Apply(stored, Item("p1", Now.AddYears(5)), Now));

        Assert.Equal(Now, stored.UpdatedAt);
    }
}
