using FieldShift.Web.DTOs;

namespace FieldShift.Web.MapLayers;

public sealed record LayerDefinition(
    string Id,
    string Name,
    string Unit,
    string Group,
    int Order,
    int Decimals,
    bool IsEstimate,
    string Source,
    string Description,
    Legend Legend,
    Legend? AnomalyLegend,
    YearlyAggregation YearlyAggregation)
{
    public bool HasAnomalies => AnomalyLegend is not null;

    public LayerDefinitionDto ToDto() => new()
    {
        Id = Id,
        Name = Name,
        Unit = Unit,
        Group = Group,
        Order = Order,
        Decimals = Decimals,
        IsEstimate = IsEstimate,
        Source = Source,
        Description = Description,
        Legend = Legend,
        AnomalyLegend = AnomalyLegend,
    };
}

/// <summary>Single source of truth for layer metadata and legends (used by both map-layers endpoints).</summary>
public static class LayerDefinitions
{
    public const string Temperature = "temperature";
    public const string HeatStress = "heatStress";
    public const string FrostRisk = "frostRisk";
    public const string Precipitation = "precipitation";
    public const string ExtremeRain = "extremeRain";
    public const string SoilMoisture = "soilMoisture";
    public const string Evaporation = "evaporation";
    public const string PlantStress = "plantStress";
    public const string ErosionRisk = "erosionRisk";
    public const string FungalRisk = "fungalRisk";
    public const string PestHeat = "pestHeat";

    private const string Climate = "Klimat";
    private const string Water = "Woda";
    private const string PlantsAndSoil = "Rośliny i gleba";

    // Colours: every sequential scale changes lightness monotonically (or uses blue/orange hues), so it stays
    // readable for colour-blind users and on top of OpenStreetMap tiles. Red vs green is never the only difference.
    private static readonly Legend RiskLegend = Sequential(
        (25, "#D9F0A3", "niski (< 25)"),
        (50, "#FEE08B", "umiarkowany (25–50)"),
        (75, "#F46D43", "wysoki (50–75)"),
        (null, "#A50026", "bardzo wysoki (≥ 75)"));

    public static readonly IReadOnlyList<LayerDefinition> All =
    [
        new(Temperature, "Temperatura", "°C", Climate, 1, 1, false,
            "NASA POWER (T2M, T2M_MAX, T2M_MIN)",
            "Średnia temperatura powietrza w miesiącu (2 m nad ziemią) – im cieplej, tym bardziej czerwony kolor.",
            Sequential(
                (0, "#2B6CB0", "mróz (< 0 °C)"),
                (10, "#9CC3E6", "chłodno (0–10 °C)"),
                (20, "#F6C27A", "umiarkowanie (10–20 °C)"),
                (null, "#C0392B", "ciepło (≥ 20 °C)")),
            Diverging(
                (-2, "#2166AC", "znacznie chłodniej niż zwykle (< −2 °C)"),
                (-0.5, "#92C5DE", "chłodniej niż zwykle (−2 do −0,5 °C)"),
                (0.5, "#F7F7F7", "jak zwykle (±0,5 °C)"),
                (2, "#F4A582", "cieplej niż zwykle (0,5–2 °C)"),
                (null, "#B2182B", "znacznie cieplej niż zwykle (≥ 2 °C)")),
            YearlyAggregation.Mean),

        new(HeatStress, "Stres cieplny", "dni", Climate, 2, 0, false,
            "NASA POWER (T2M_MAX)",
            "Liczba dni w miesiącu z temperaturą powyżej 30 °C – im więcej, tym większy stres cieplny dla roślin.",
            Sequential(
                (1, "#FFF3D6", "brak upałów (0 dni)"),
                (4, "#FDBE6E", "kilka dni upału (1–3 dni)"),
                (10, "#E8692C", "częste upały (4–9 dni)"),
                (null, "#8C1D18", "bardzo częste upały (≥ 10 dni)")),
            null, YearlyAggregation.Sum),

        new(FrostRisk, "Ryzyko mrozu", "dni", Climate, 3, 0, false,
            "NASA POWER (T2M_MIN)",
            "Liczba dni w miesiącu z temperaturą poniżej 0 °C – im więcej, tym większe ryzyko uszkodzeń mrozowych.",
            Sequential(
                (1, "#F1F5FB", "bez mrozu (0 dni)"),
                (6, "#B9D3EE", "kilka dni mrozu (1–5 dni)"),
                (16, "#5B8FCB", "częsty mróz (6–15 dni)"),
                (null, "#1E3F7A", "długi mróz (≥ 16 dni)")),
            null, YearlyAggregation.Sum),

        new(Precipitation, "Opady", "mm", Water, 4, 0, false,
            "NASA POWER (PRECTOTCORR)",
            "Suma opadów w miesiącu – ciemniejszy niebieski oznacza więcej wody.",
            Sequential(
                (20, "#F5E6C8", "bardzo sucho (< 20 mm)"),
                (40, "#B5D4F4", "sucho (20–40 mm)"),
                (70, "#378ADD", "normalnie (40–70 mm)"),
                (null, "#0C447C", "mokro (≥ 70 mm)")),
            Diverging(
                (-30, "#B2182B", "znacznie suszej niż zwykle (< −30 mm)"),
                (-10, "#F4A582", "suszej niż zwykle (−30 do −10 mm)"),
                (10, "#F7F7F7", "jak zwykle (±10 mm)"),
                (30, "#92C5DE", "mokrzej niż zwykle (10–30 mm)"),
                (null, "#2166AC", "znacznie mokrzej niż zwykle (≥ 30 mm)")),
            YearlyAggregation.Sum),

        new(ExtremeRain, "Ekstremalne opady", "dni", Water, 5, 0, false,
            "NASA POWER (PRECTOTCORR)",
            "Liczba dni w miesiącu z ulewą powyżej 20 mm – takie deszcze zmywają glebę i zalewają pola.",
            Sequential(
                (1, "#F3EEF8", "brak ulew (0 dni)"),
                (2, "#C6B4E0", "1 dzień z ulewą"),
                (3, "#8C6BC2", "2 dni z ulewą"),
                (null, "#4B2A85", "częste ulewy (≥ 3 dni)")),
            null, YearlyAggregation.Sum),

        new(SoilMoisture, "Wilgotność gleby", "0–1", Water, 6, 2, false,
            "NASA POWER (GWETROOT)",
            "Wilgotność gleby w strefie korzeni (0 = sucho, 1 = nasycona wodą) – brązowy kolor oznacza suszę.",
            Sequential(
                (0.35, "#8C5A2B", "sucho (< 0,35)"),
                (0.45, "#D9B77E", "umiarkowanie sucho (0,35–0,45)"),
                (0.55, "#8FC1E3", "wilgotno (0,45–0,55)"),
                (null, "#2166AC", "bardzo wilgotno (≥ 0,55)")),
            Diverging(
                (-0.08, "#B2182B", "znacznie suszej niż zwykle (< −0,08)"),
                (-0.03, "#F4A582", "suszej niż zwykle (−0,08 do −0,03)"),
                (0.03, "#F7F7F7", "jak zwykle (±0,03)"),
                (0.08, "#92C5DE", "wilgotniej niż zwykle (0,03–0,08)"),
                (null, "#2166AC", "znacznie wilgotniej niż zwykle (≥ 0,08)")),
            YearlyAggregation.Mean),

        new(Evaporation, "Parowanie", "mm", Water, 7, 0, false,
            "NASA POWER (EVPTRNS, przeliczone z MJ/m² na mm)",
            "Woda, która w miesiącu faktycznie wyparowała z gleby i roślin (wg modelu) – sucha gleba paruje mniej, więc niska wartość latem może oznaczać suszę.",
            Sequential(
                (30, "#FFF7D1", "małe parowanie (< 30 mm)"),
                (60, "#F5D76E", "umiarkowane parowanie (30–60 mm)"),
                (90, "#E3A33A", "duże parowanie (60–90 mm)"),
                (null, "#A8641A", "bardzo duże parowanie (≥ 90 mm)")),
            null, YearlyAggregation.Sum),

        new(PlantStress, "Stres roślinny (szacunek)", "0–100", PlantsAndSoil, 8, 0, true,
            "Szacunek z NASA POWER (GWETROOT, T2M_MAX)",
            "Szacunkowy stres roślin (0–100) z suchości gleby i liczby upalnych dni – im wyżej, tym trudniej roślinom.",
            RiskLegend, null, YearlyAggregation.Mean),

        new(ErosionRisk, "Ryzyko erozji (szacunek)", "0–100", PlantsAndSoil, 9, 0, true,
            "Szacunek z NASA POWER (PRECTOTCORR), ISRIC SoilGrids i nachylenia terenu (NASA SRTM)",
            "Szacunkowe ryzyko erozji wodnej: ulewy w miesiącu, podatność gleby i nachylenie terenu (uproszczone czynniki R, K i LS modelu RUSLE).",
            RiskLegend, null, YearlyAggregation.Mean),

        new(FungalRisk, "Pogoda sprzyjająca chorobom grzybowym (szacunek)", "dni", PlantsAndSoil, 10, 0, true,
            "Szacunek z NASA POWER (T2M, RH2M, PRECTOTCORR)",
            "Liczba dni w miesiącu, gdy pogoda sprzyja chorobom grzybowym (np. zaraza ziemniaka, mączniaki, rdze): "
            + "średnio 10–25 °C i bardzo wilgotne powietrze (≥ 85 %) albo wilgotne (≥ 75 %) z deszczem. "
            + "To nie jest wykrycie choroby – tylko sygnał, że warto obejrzeć rośliny.",
            Sequential(
                (3, "#EEF6EA", "rzadko (0–2 dni)"),
                (8, "#B9DDB0", "czasem (3–7 dni)"),
                (15, "#5FA36A", "często (8–14 dni)"),
                (null, "#1F5E3B", "bardzo często (≥ 15 dni)")),
            null, YearlyAggregation.Sum),

        new(PestHeat, "Ciepło sprzyjające szkodnikom (szacunek)", "°C·dni", PlantsAndSoil, 11, 0, true,
            "Szacunek z NASA POWER (T2M): suma stopniodni powyżej 10 °C od 1 stycznia",
            "Ciepło zebrane od początku roku (stopniodni powyżej 10 °C). Od niego zależy, jak szybko rozwijają się owady, "
            + "np. stonka ziemniaczana czy omacnica prosowianka – im więcej, tym więcej ich pokoleń może się pojawić. "
            + "To nie jest wykrycie szkodników.",
            Sequential(
                (100, "#FFF5EB", "owady w spoczynku (< 100)"),
                (400, "#FDD0A2", "początek rozwoju owadów (100–400)"),
                (800, "#F98E3D", "szybki rozwój owadów (400–800)"),
                (null, "#A63603", "wiele pokoleń owadów (≥ 800)")),
            null, YearlyAggregation.Mean),
    ];

    private static readonly Dictionary<string, LayerDefinition> ById =
        All.ToDictionary(d => d.Id, StringComparer.OrdinalIgnoreCase);

    public static LayerDefinition? Find(string id) => ById.GetValueOrDefault(id);

    /// <summary>The legend stop a value falls into: the first stop with <c>value &lt; max</c> (last stop catches the rest).</summary>
    public static LegendStop? StopFor(Legend legend, double? value)
    {
        if (value is not { } v || legend.Stops.Count == 0)
        {
            return null;
        }

        return legend.Stops.FirstOrDefault(s => s.Max is null || v < s.Max) ?? legend.Stops[^1];
    }

    private static Legend Sequential(params (double? Max, string Color, string Label)[] stops) => Make("sequential", stops);
    private static Legend Diverging(params (double? Max, string Color, string Label)[] stops) => Make("diverging", stops);

    private static Legend Make(string type, (double? Max, string Color, string Label)[] stops) => new()
    {
        Type = type,
        Stops = stops.Select(s => new LegendStop { Max = s.Max, Color = s.Color, Label = s.Label }).ToList(),
    };
}
