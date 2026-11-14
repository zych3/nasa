namespace FieldShift.Web.FieldProfile;

/// <summary>Polish month names in the grammatical cases used by the summary sentences.</summary>
internal static class PolishMonths
{
    /// <summary>Mianownik: "kwiecień–październik".</summary>
    public static readonly string[] Nominative =
    [
        "styczeń", "luty", "marzec", "kwiecień", "maj", "czerwiec",
        "lipiec", "sierpień", "wrzesień", "październik", "listopad", "grudzień",
    ];

    /// <summary>Dopełniacz: "do maja", "od września".</summary>
    public static readonly string[] Genitive =
    [
        "stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca",
        "lipca", "sierpnia", "września", "października", "listopada", "grudnia",
    ];

    /// <summary>Miejscownik: "w sierpniu".</summary>
    public static readonly string[] Locative =
    [
        "styczniu", "lutym", "marcu", "kwietniu", "maju", "czerwcu",
        "lipcu", "sierpniu", "wrześniu", "październiku", "listopadzie", "grudniu",
    ];

    /// <summary>"w sierpniu i wrześniu", "we wrześniu", "w lipcu, sierpniu i wrześniu" (1-based months).</summary>
    public static string InList(IReadOnlyList<int> months)
    {
        var names = months.Select(m => Locative[m - 1]).ToList();
        var joined = names.Count == 1
            ? names[0]
            : string.Join(", ", names.Take(names.Count - 1)) + " i " + names[^1];
        var preposition = months[0] == 9 ? "we" : "w"; // "we wrześniu"
        return $"{preposition} {joined}";
    }
}
