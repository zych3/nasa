using System.Globalization;
using System.Text.RegularExpressions;

namespace FieldShift.Web.MapLayers;

/// <summary>A calendar month, formatted "yyyy-MM".</summary>
public readonly partial record struct YearMonth(int Year, int Month) : IComparable<YearMonth>
{
    /// <summary>Months since year 0, so differences between months are plain subtraction.</summary>
    public int Index => Year * 12 + (Month - 1);

    public int DaysInMonth => DateTime.DaysInMonth(Year, Month);
    public DateOnly FirstDay => new(Year, Month, 1);
    public DateOnly LastDay => new(Year, Month, DaysInMonth);

    public static YearMonth From(DateOnly date) => new(date.Year, date.Month);
    public static YearMonth FromIndex(int index) => new(index / 12, index % 12 + 1);
    public YearMonth AddMonths(int months) => FromIndex(Index + months);

    /// <summary>All months from <paramref name="from"/> to <paramref name="to"/>, inclusive.</summary>
    public static IReadOnlyList<YearMonth> Range(YearMonth from, YearMonth to) =>
        Enumerable.Range(from.Index, Math.Max(0, to.Index - from.Index + 1)).Select(FromIndex).ToList();

    /// <summary>Parses exactly "yyyy-MM" (month 01–12).</summary>
    public static bool TryParse(string? text, out YearMonth value)
    {
        value = default;
        if (text is null || !FormatRegex().IsMatch(text))
        {
            return false;
        }

        var year = int.Parse(text.AsSpan(0, 4), CultureInfo.InvariantCulture);
        var month = int.Parse(text.AsSpan(5, 2), CultureInfo.InvariantCulture);
        if (month is < 1 or > 12)
        {
            return false;
        }

        value = new YearMonth(year, month);
        return true;
    }

    public int CompareTo(YearMonth other) => Index.CompareTo(other.Index);
    public static bool operator <(YearMonth a, YearMonth b) => a.Index < b.Index;
    public static bool operator >(YearMonth a, YearMonth b) => a.Index > b.Index;
    public static bool operator <=(YearMonth a, YearMonth b) => a.Index <= b.Index;
    public static bool operator >=(YearMonth a, YearMonth b) => a.Index >= b.Index;

    public override string ToString() => string.Create(CultureInfo.InvariantCulture, $"{Year:D4}-{Month:D2}");

    [GeneratedRegex(@"^\d{4}-\d{2}$")]
    private static partial Regex FormatRegex();
}
