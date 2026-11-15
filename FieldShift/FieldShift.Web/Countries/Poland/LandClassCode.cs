using System.Text.RegularExpressions;
using FieldShift.Web.FieldData;

namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Reads land class codes of the Polish land register (EGiB), e.g. "RIVb" (arable land, soil quality class IVb),
/// "LzrRIVb" or "Lzr-RIVb" (wooded land on arable land of class IVb), "ŁIII", "PsV", "N", "dr".
/// <para>Form: [land use form][-]land use + class, after the regulation on the land register (EGiB) and the soil
/// classification of land (classes I–VI, arable III and IV split into a/b, VIz = for afforestation).</para>
/// </summary>
public static partial class LandClassCode
{
    /// <summary>Land use codes (register) → plain Polish words.</summary>
    private static readonly Dictionary<string, string> LandUses = new(StringComparer.Ordinal)
    {
        ["R"] = "grunty orne",
        ["Ł"] = "łąki trwałe",
        ["Ps"] = "pastwiska trwałe",
        ["S"] = "sady",
        ["Br"] = "grunty rolne zabudowane",
        ["Wsr"] = "grunty pod stawami",
        ["W"] = "grunty pod rowami",
        ["Lzr"] = "grunty zadrzewione i zakrzewione na użytkach rolnych",
        ["Ls"] = "lasy",
        ["Lz"] = "grunty zadrzewione i zakrzewione",
        ["B"] = "tereny mieszkaniowe",
        ["Ba"] = "tereny przemysłowe",
        ["Bi"] = "inne tereny zabudowane",
        ["Bp"] = "zurbanizowane tereny niezabudowane",
        ["Bz"] = "tereny rekreacyjno-wypoczynkowe",
        ["K"] = "użytki kopalne",
        ["dr"] = "drogi",
        ["Tk"] = "tereny kolejowe",
        ["Ti"] = "inne tereny komunikacyjne",
        ["Tp"] = "grunty przeznaczone pod budowę dróg",
        ["Wm"] = "grunty pod morskimi wodami wewnętrznymi",
        ["Wp"] = "grunty pod wodami powierzchniowymi płynącymi",
        ["Ws"] = "grunty pod wodami powierzchniowymi stojącymi",
        ["Tr"] = "tereny różne",
        ["N"] = "nieużytki",
    };

    /// <summary>Official names of the soil quality classes of arable land.</summary>
    private static readonly Dictionary<string, string> ArableClasses = new(StringComparer.Ordinal)
    {
        ["I"] = "orne najlepsze",
        ["II"] = "orne bardzo dobre",
        ["IIIa"] = "orne dobre",
        ["IIIb"] = "orne średnio dobre",
        ["IVa"] = "orne średnie lepsze",
        ["IVb"] = "orne średnie gorsze",
        ["V"] = "orne słabe",
        ["VI"] = "orne najsłabsze",
        ["VIz"] = "pod zalesienie",
    };

    /// <summary>Official names of the classes of meadows and pastures (and of other land with a class).</summary>
    private static readonly Dictionary<string, string> GrasslandClasses = new(StringComparer.Ordinal)
    {
        ["I"] = "najlepsze",
        ["II"] = "bardzo dobre",
        ["III"] = "dobre",
        ["IV"] = "średnie",
        ["V"] = "słabe",
        ["VI"] = "najsłabsze",
        ["VIz"] = "pod zalesienie",
    };

    [GeneratedRegex(@"^(?:(?<form>[A-Za-zŁł]+?)-?)??(?<use>R|Ł|Ps|Ls|Lz)(?<class>VI|V|IV|III|II|I)(?<sub>[ab]|z)?$")]
    private static partial Regex WithClass();

    /// <summary>One code → a <see cref="LandClass"/>; unknown codes keep the code as the land use word.</summary>
    public static LandClass Parse(string code)
    {
        code = code.Trim();
        var match = WithClass().Match(code);
        if (!match.Success)
        {
            return new LandClass { Code = code, LandUse = LandUseName(code.Split('-')[0]) };
        }

        var form = match.Groups["form"].Value;
        var use = match.Groups["use"].Value;
        var quality = match.Groups["class"].Value + match.Groups["sub"].Value;
        var names = use == "R" ? ArableClasses : GrasslandClasses;
        var landUse = form.Length > 0 && form != use
            ? $"{LandUseName(form)} ({LandUseName(use)})"
            : LandUseName(use);

        return new LandClass
        {
            Code = code,
            LandUse = landUse,
            QualityClass = quality,
            QualityName = names.GetValueOrDefault(quality),
        };
    }

    /// <summary>A comma-separated list as the register writes it ("LzrRIVb,RIVb"); duplicates and blanks dropped.</summary>
    public static IReadOnlyList<LandClass> ParseList(string? codes) =>
        (codes ?? "")
        .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .Distinct(StringComparer.Ordinal)
        .Select(Parse)
        .ToList();

    private static string LandUseName(string code) => LandUses.GetValueOrDefault(code, code);
}
