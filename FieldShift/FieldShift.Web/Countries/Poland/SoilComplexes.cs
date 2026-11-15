namespace FieldShift.Web.Countries.Poland;

/// <summary>
/// Codes of the Polish soil-agricultural map (mapa glebowo-rolnicza, 1:5000) → names, copied from the map's legends:
/// "Legenda do przestrzennej bazy danych glebowych" (Geoportal Podlaskie) and the legend image of GUGiK's WMS
/// (GetLegendGraphic), which has more subtypes ("…d" = deluvial) and writes ż / ł where the PDF has z / l.
/// Unknown codes stay as they are.
/// </summary>
public static class SoilComplexes
{
    /// <summary>Agricultural suitability complexes (kompleksy rolniczej przydatności gleb) and other areas.</summary>
    private static readonly Dictionary<string, string> Complexes = new(StringComparer.Ordinal)
    {
        ["1"] = "kompleks pszenny bardzo dobry",
        ["2"] = "kompleks pszenny dobry",
        ["3"] = "kompleks pszenny wadliwy",
        ["4"] = "kompleks żytni bardzo dobry (pszenno-żytni)",
        ["5"] = "kompleks żytni dobry",
        ["6"] = "kompleks żytni słaby",
        ["7"] = "kompleks żytni bardzo słaby (żytnio-łubinowy)",
        ["8"] = "kompleks zbożowo-pastewny mocny",
        ["9"] = "kompleks zbożowo-pastewny słaby",
        ["10"] = "kompleks pszenny górski",
        ["11"] = "kompleks zbożowy górski",
        ["12"] = "kompleks owsiano-ziemniaczany górski",
        ["13"] = "kompleks owsiano-pastewny górski",
        ["14"] = "gleby orne przeznaczone pod użytki zielone",
        ["1z"] = "użytki zielone bardzo dobre i dobre",
        ["2z"] = "użytki zielone średnie",
        ["3z"] = "użytki zielone słabe i bardzo słabe",
        ["RN"] = "gleby rolniczo nieprzydatne (nadające się pod zalesienie)",
        ["Ls"] = "lasy",
        ["Tz"] = "tereny zabudowane",
        ["W"] = "wody",
        ["WN"] = "wody nieużytki i bagna",
        ["N"] = "nieużytki rolnicze",
        ["GO"] = "grunty orne",
        ["TUZ"] = "trwałe użytki zielone",
        ["Tnk"] = "tereny nieklasyfikowane",
    };

    /// <summary>Soil types and subtypes (typy i podtypy gleb).</summary>
    private static readonly Dictionary<string, string> SoilTypes = new(StringComparer.Ordinal)
    {
        ["A"] = "gleby bielicowe i pseudobielicowe",
        ["Ax"] = "gleby pseudobielicowe",
        ["AB"] = "kompleks gleb pseudobielicowych i brunatnych",
        ["B"] = "gleby brunatne właściwe",
        ["Bw"] = "gleby brunatne wyługowane i brunatne kwaśne",
        ["C"] = "czarnoziemy właściwe",
        ["Cz"] = "czarnoziemy zdegradowane i gleby szare",
        ["D"] = "czarne ziemie właściwe",
        ["Dz"] = "czarne ziemie zdegradowane i gleby szare",
        ["G"] = "gleby glejowe",
        ["E"] = "gleby mułowo-torfowe i torfowo-mułowe",
        ["M"] = "gleby murszowo-mineralne i murszowate",
        ["T"] = "gleby torfowe i murszowo-torfowe",
        ["F"] = "mady",
        ["Fb"] = "mady brunatne",
        ["Fc"] = "mady czarnoziemne",
        ["FG"] = "gleby aluwialne glejowe",
        ["R"] = "rędziny o słabo wykształconym profilu",
        ["Rb"] = "rędziny brunatne",
        ["Ad"] = "gleby bielicowe właściwe i pseudobielicowe deluwialne",
        ["Bd"] = "gleby brunatne deluwialne",
        ["Bk"] = "gleby brunatne kwaśne",
        ["Bkd"] = "gleby brunatne kwaśne deluwialne",
        ["Bwd"] = "gleby brunatne wyługowane deluwialne",
        ["Cd"] = "czarnoziemy właściwe deluwialne",
        ["Czd"] = "czarnoziemy zdegradowane i gleby szare deluwialne",
        ["Dd"] = "czarne ziemie właściwe deluwialne",
        ["DG"] = "czarne ziemie glejowe",
        ["DGd"] = "czarne ziemie glejowe deluwialne",
        ["Dzd"] = "czarne ziemie zdegradowane i ziemie szare deluwialne",
        ["DzG"] = "czarne ziemie zdegradowane i ziemie szare glejowe",
        ["DzGd"] = "czarne ziemie zdegradowane i ziemie szare glejowe deluwialne",
        ["Emt"] = "gleby mułowo-torfowe",
        ["Etm"] = "gleby torfowo-mułowe",
        ["Fd"] = "mady deluwialne",
        ["FGd"] = "mady glejowe deluwialne",
        ["Gd"] = "gleby glejowe deluwialne",
        ["Md"] = "gleby murszowo-mineralne i murszowate deluwialne",
        ["Rc"] = "rędziny próchniczne (czarnoziemne i szare)",
        ["Rd"] = "rędziny deluwialne (namyte)",
        ["Rg"] = "rędziny gipsowe (siarczanowe)",
    };

    /// <summary>Kinds and textures of soils (rodzaje i gatunki gleb) and other rocks.</summary>
    private static readonly Dictionary<string, string> Textures = new(StringComparer.Ordinal)
    {
        ["z"] = "gleby żwirowe",
        ["zp"] = "żwiry piaszczyste",
        ["zg"] = "żwiry gliniaste",
        ["p"] = "gleby piaszczyste",
        ["pl"] = "piaski luźne",
        ["ps"] = "piaski słabogliniaste",
        ["pgl"] = "piaski gliniaste lekkie",
        ["pgm"] = "piaski gliniaste mocne",
        ["plw"] = "piaski wydmowe",
        ["gl"] = "gliny lekkie",
        ["gs"] = "gliny średnie",
        ["gc"] = "gliny ciężkie",
        ["plz"] = "pyły zwykłe",
        ["pli"] = "pyły ilaste",
        ["l"] = "lessy i utwory lessowate",
        ["li"] = "lessy i utwory lessowate ilaste",
        ["ip"] = "iły pylaste",
        ["i"] = "iły",
        ["ic"] = "iły ciężkie",
        ["ibc"] = "iły bardzo ciężkie",
        ["dl"] = "deluwia lekkie",
        ["ds"] = "deluwia średnie",
        ["dc"] = "deluwia ciężkie",
        ["n"] = "torfy niskie",
        ["v"] = "torfy przejściowe i wysokie",
        ["mt"] = "gleby mułowo-torfowe",
        ["tm"] = "gleby torfowo-mułowe",
        ["sk"] = "skała lita",
        ["r"] = "rumosz skalny",
        ["sz"] = "gleby szkieletowe",
        ["wl"] = "wapno łąkowe",
        ["ga"] = "gytia",
        ["t"] = "skała organogeniczna (torf)",
        ["żp"] = "żwiry piaszczyste",
        ["żg"] = "żwiry gliniaste",
        ["płz"] = "pyły zwykłe",
        ["płi"] = "pyły ilaste",
        ["pł"] = "gleby pyłowe",
        ["g"] = "gleby gliniaste",
        ["w"] = "skała wapienna",
        ["d"] = "utwory deluwialne",
        ["m"] = "mursz",
    };

    /// <summary>Rendzinas (soil types R, Rb) use l / s / c for their own textures.</summary>
    private static readonly Dictionary<string, string> RendzinaTextures = new(StringComparer.Ordinal)
    {
        ["l"] = "rędziny lekkie",
        ["s"] = "rędziny średnie",
        ["c"] = "rędziny ciężkie",
    };

    /// <summary>Alluvial soils (soil types F, Fb, Fc, FG) use bl … bc for their own textures.</summary>
    private static readonly Dictionary<string, string> AlluvialTextures = new(StringComparer.Ordinal)
    {
        ["bl"] = "mady bardzo lekkie",
        ["l"] = "mady lekkie",
        ["s"] = "mady średnie",
        ["c"] = "mady ciężkie",
        ["bc"] = "mady bardzo ciężkie",
    };

    /// <summary>Depth marks before a deeper layer: where the texture changes.</summary>
    private static readonly Dictionary<string, string> Depths = new(StringComparer.Ordinal)
    {
        ["-"] = "do 25 cm",
        ["."] = "25–50 cm",
        [":"] = "50–100 cm",
        [":."] = "100–150 cm",
    };

    public static string? ComplexName(string? code) => code is null ? null : Complexes.GetValueOrDefault(code);

    public static string? SoilTypeName(string? code) => code is null ? null : SoilTypes.GetValueOrDefault(code);

    public static string? DepthName(string? mark) => mark is null ? null : Depths.GetValueOrDefault(mark);

    /// <summary>
    /// Name of a texture code for a soil type; a trailing "p" (e.g. "gsp") means silty ("pylaste"). The code
    /// itself when unknown.
    /// </summary>
    public static string TextureName(string code, string? soilType)
    {
        var own = soilType switch
        {
            "R" or "Rb" => RendzinaTextures,
            "F" or "Fb" or "Fc" or "FG" => AlluvialTextures,
            _ => null,
        };
        if (own?.GetValueOrDefault(code) is { } special)
        {
            return special;
        }

        if (Textures.TryGetValue(code, out var name))
        {
            return name;
        }

        return code.Length > 1 && code.EndsWith('p') && Textures.TryGetValue(code[..^1], out var silty)
            ? $"{silty} pylaste"
            : code;
    }
}
