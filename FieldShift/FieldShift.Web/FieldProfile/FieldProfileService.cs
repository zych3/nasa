using System.Text.RegularExpressions;
using FieldShift.Web.DTOs;

namespace FieldShift.Web.FieldProfile;

/// <summary>
/// Pure calculation logic: turns parsed NASA POWER + SoilGrids data into a <see cref="FieldProfileResponse"/>.
/// No HTTP, cache, logging or clock, so it can be unit-tested on saved JSON fixtures.
/// </summary>
public sealed partial class FieldProfileService
{
    public const string Disclaimer =
        "Dane wspierają decyzję rolnika, ale jej nie zastępują. Skonsultuj wnioski z lokalnym doradcą rolnym.";

    public const string SoilUnavailableWarning =
        "Nie udało się pobrać danych glebowych (ISRIC SoilGrids) – wybierz typ gleby ręcznie.";

    public const string SoilNoDataWarning =
        "Brak danych glebowych dla tego punktu (np. zabudowa lub woda) – wybierz typ gleby ręcznie.";

    public const string SocTopLayerSkippedWarning =
        "Pominięto warstwę 0–5 cm dla węgla organicznego (wartość zawyżona względem warstw głębszych).";

    public const string NitrogenTopLayerSkippedWarning =
        "Pominięto warstwę 0–5 cm dla azotu (wartość zawyżona względem warstw głębszych).";

    private static readonly int[] DaysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    // Layer thickness in cm, used as weights for the 0–30 cm average (same order as SoilGridsClient.Depths).
    private static readonly double[] DepthWeights = [5, 10, 15];

    private static readonly Dictionary<string, string> MissingParameterLabels = new()
    {
        ["T2M"] = "średniej temperatury",
        ["T2M_MIN"] = "temperatury minimalnej",
        ["T2M_MAX"] = "temperatury maksymalnej",
        ["PRECTOTCORR"] = "opadów",
        ["GWETROOT"] = "wilgotności gleby",
    };

    public FieldProfileResponse Build(
        double lat,
        double lon,
        NasaPowerData nasa,
        SoilGridsData? soilData,
        DateTimeOffset generatedAtUtc)
    {
        var warnings = new List<string>();
        var climate = BuildClimate(nasa, warnings);
        var soil = BuildSoil(soilData, warnings);

        return new FieldProfileResponse
        {
            Location = new LocationInfo
            {
                Lat = lat,
                Lon = lon,
                ElevationM = nasa.ElevationM is { } e ? (int)Math.Round(e, MidpointRounding.AwayFromZero) : null,
            },
            Climate = climate,
            Soil = soil,
            Summary = BuildSummary(climate, soil),
            Warnings = warnings,
            Disclaimer = Disclaimer,
            GeneratedAtUtc = generatedAtUtc,
        };
    }

    // ---------------------------------------------------------------- climate

    private static ClimateProfile BuildClimate(NasaPowerData nasa, List<string> warnings)
    {
        var avgTemp = nasa.Get("T2M");
        var minTemp = nasa.Get("T2M_MIN");
        var maxTemp = nasa.Get("T2M_MAX");
        var precipPerDay = nasa.Get("PRECTOTCORR");
        var soilMoisture = nasa.Get("GWETROOT");

        AddMissingDataWarnings(nasa, warnings);

        var precipitation = new double?[12];
        for (var i = 0; i < 12; i++)
        {
            precipitation[i] = precipPerDay[i] is { } p ? Round(p * DaysInMonth[i], 1) : null;
        }

        var growingSeason = MonthsWhere(avgTemp, t => t > 5);
        var frost = MonthsWhere(minTemp, t => t < 0);

        int? dropPct = null;
        IReadOnlyList<int> dryMonths = [];
        var moisture = soilMoisture.OfType<double>().ToList();
        if (moisture.Count > 0)
        {
            var min = moisture.Min();
            var max = moisture.Max();
            // Small epsilon so a month exactly at min + 0.01 is included despite floating-point error.
            dryMonths = MonthsWhere(soilMoisture, v => v <= min + 0.01 + 1e-9);
            if (max > 0)
            {
                dropPct = (int)Math.Round((max - min) / max * 100, MidpointRounding.AwayFromZero);
            }
        }

        return new ClimateProfile
        {
            Source = BuildClimateSource(nasa.Range),
            Description = "Typowy klimat lokalizacji: średnie miesięczne z wielolecia. Indeks tablic 0 = styczeń.",
            AvgTempC = avgTemp,
            MinTempC = minTemp,
            MaxTempC = maxTemp,
            PrecipitationMm = precipitation,
            SoilMoisture = soilMoisture,
            GrowingSeasonMonths = growingSeason,
            GrowingSeasonDays = growingSeason.Sum(m => DaysInMonth[m - 1]),
            AnnualPrecipitationMm = SumOrNull(precipitation),
            SeasonPrecipitationMm = SumOrNull(precipitation[3..9]), // April (index 3) … September (index 8)
            FrostRiskMonths = frost,
            LastSpringFrostMonth = frost.Where(m => m <= 6).Select(m => (int?)m).Max(),
            FirstAutumnFrostMonth = frost.Where(m => m >= 7).Select(m => (int?)m).Min(),
            HeatRiskMonths = MonthsWhere(maxTemp, t => t > 30),
            DryMonths = dryMonths,
            SoilMoistureDropPct = dropPct,
        };
    }

    private static void AddMissingDataWarnings(NasaPowerData nasa, List<string> warnings)
    {
        foreach (var name in NasaPowerClient.ParameterNames)
        {
            var values = nasa.Get(name);
            var missing = Enumerable.Range(1, 12).Where(m => values[m - 1] is null).ToList();
            if (missing.Count == 0)
            {
                continue;
            }

            var months = missing.Count == 12
                ? "wszystkich miesięcy"
                : "miesięcy: " + string.Join(", ", missing.Select(m => PolishMonths.Nominative[m - 1]));
            warnings.Add($"Brak danych NASA POWER dla {MissingParameterLabels[name]} ({months}) – pominięto je w obliczeniach.");
        }
    }

    private static string BuildClimateSource(string? range)
    {
        // header.range looks like "January 2001 - December 2025" (sometimes with extra text around it).
        var years = YearRegex().Matches(range ?? string.Empty);
        var period = years.Count >= 2 ? $"{years[0].Value}–{years[^1].Value}" : "wieloletnia";
        return $"NASA POWER, klimatologia {period} (siatka MERRA-2 ~50 km)";
    }

    [GeneratedRegex(@"\b(?:19|20)\d{2}\b")]
    private static partial Regex YearRegex();

    // ---------------------------------------------------------------- soil

    private static SoilProfile? BuildSoil(SoilGridsData? data, List<string> warnings)
    {
        if (data is null)
        {
            warnings.Add(SoilUnavailableWarning);
            return null;
        }

        var sandLayers = LayerValues(data, "sand");
        var clayLayers = LayerValues(data, "clay");
        var siltLayers = LayerValues(data, "silt");
        var phLayers = LayerValues(data, "phh2o");
        var socLayers = LayerValues(data, "soc");
        var nitrogenLayers = LayerValues(data, "nitrogen");
        var cecLayers = LayerValues(data, "cec");
        var bulkDensityLayers = LayerValues(data, "bdod");
        var coarseLayers = LayerValues(data, "cfvo");

        double?[][] all =
        [
            sandLayers, clayLayers, siltLayers, phLayers, socLayers,
            nitrogenLayers, cecLayers, bulkDensityLayers, coarseLayers,
        ];
        if (all.All(l => l.All(v => v is null)))
        {
            warnings.Add(SoilNoDataWarning);
            return null;
        }

        // On arable land SoilGrids often overestimates organic carbon and nitrogen in the top 0–5 cm.
        SkipInflatedTopLayer(socLayers, SocTopLayerSkippedWarning, warnings);
        SkipInflatedTopLayer(nitrogenLayers, NitrogenTopLayerSkippedWarning, warnings);

        var sand = RoundOrNull(WeightedAverage(sandLayers), 1);
        var clay = RoundOrNull(WeightedAverage(clayLayers), 1);
        var silt = RoundOrNull(WeightedAverage(siltLayers), 1);
        var ph = RoundOrNull(WeightedAverage(phLayers), 2);
        var soc = RoundOrNull(WeightedAverage(socLayers), 1);
        var nitrogen = RoundOrNull(WeightedAverage(nitrogenLayers), 2);
        var cec = RoundOrNull(WeightedAverage(cecLayers), 1);
        var bulkDensity = RoundOrNull(WeightedAverage(bulkDensityLayers), 2);
        var coarse = RoundOrNull(WeightedAverage(coarseLayers), 1);
        var soilClass = ClassifySoil(sand, clay);

        return new SoilProfile
        {
            Source = "ISRIC SoilGrids v2.0, warstwa 0–30 cm (rozdzielczość 250 m)",
            Description = "Skład i właściwości gleby oszacowane modelem; rolnik może je poprawić.",
            SandPct = sand,
            ClayPct = clay,
            SiltPct = silt,
            Ph = ph,
            OrganicCarbonGkg = soc,
            NitrogenGkg = nitrogen,
            CecCmolKg = cec,
            BulkDensityGcm3 = bulkDensity,
            CoarseFragmentsPct = coarse,
            SoilClass = soilClass,
            PhClass = ClassifyPh(ph),
            OrganicMatterClass = ClassifyOrganicMatter(soc),
            NitrogenClass = ClassifyLowMediumHigh(nitrogen, 1, 2),
            CecClass = ClassifyLowMediumHigh(cec, 10, 20),
            CompactionClass = ClassifyCompaction(bulkDensity, soilClass),
            StoneClass = ClassifyStones(coarse),
        };
    }

    /// <summary>Drops the 0–5 cm value when it is more than 2× the 5–15 cm value (typical model overestimate).</summary>
    private static void SkipInflatedTopLayer(double?[] layers, string warning, List<string> warnings)
    {
        if (layers[0] is { } top && layers[1] is { } mid && top > 2 * mid)
        {
            layers[0] = null;
            warnings.Add(warning);
        }
    }

    /// <summary>Values in target units for the 3 depths (mean / d_factor); null where missing.</summary>
    private static double?[] LayerValues(SoilGridsData data, string name)
    {
        var values = new double?[SoilGridsClient.Depths.Length];
        var layer = data.Layers.FirstOrDefault(l => string.Equals(l.Name, name, StringComparison.OrdinalIgnoreCase));
        if (layer is null)
        {
            return values;
        }

        for (var i = 0; i < values.Length; i++)
        {
            if (layer.MeanByDepth.TryGetValue(SoilGridsClient.Depths[i], out var mean) && mean is { } m)
            {
                values[i] = m / layer.DFactor;
            }
        }

        return values;
    }

    private static double? WeightedAverage(double?[] layers)
    {
        double sum = 0, weights = 0;
        for (var i = 0; i < layers.Length; i++)
        {
            if (layers[i] is { } v)
            {
                sum += v * DepthWeights[i];
                weights += DepthWeights[i];
            }
        }

        return weights > 0 ? sum / weights : null;
    }

    private static string? ClassifySoil(double? sand, double? clay) => (sand, clay) switch
    {
        ({ } s, _) when s > 65 => "Lekka",
        (_, { } c) when c > 30 => "Ciężka",
        (null, null) => null,
        _ => "Średnia",
    };

    private static string? ClassifyPh(double? ph) => ph switch
    {
        null => null,
        < 5.5 => "Kwaśna",
        <= 6.5 => "Lekko kwaśna",
        <= 7.2 => "Obojętna",
        _ => "Zasadowa",
    };

    private static string? ClassifyOrganicMatter(double? soc) => ClassifyLowMediumHigh(soc, 10, 20);

    private static string? ClassifyLowMediumHigh(double? value, double low, double high) => value switch
    {
        null => null,
        { } v when v < low => "Niska",
        { } v when v <= high => "Średnia",
        _ => "Wysoka",
    };

    // Simplified from USDA NRCS bulk density guidance: lighter (sandier) soils tolerate higher density.
    private static string? ClassifyCompaction(double? bulkDensity, string? soilClass)
    {
        if (bulkDensity is not { } bd)
        {
            return null;
        }

        var threshold = soilClass switch
        {
            "Lekka" => 1.60,
            "Ciężka" => 1.40,
            _ => 1.50,
        };
        return bd > threshold ? "Zagęszczona" : "Prawidłowa";
    }

    private static string? ClassifyStones(double? coarsePct) => coarsePct switch
    {
        null => null,
        < 5 => "Mała",
        <= 15 => "Średnia",
        _ => "Duża",
    };

    // ---------------------------------------------------------------- summary

    private static List<string> BuildSummary(ClimateProfile climate, SoilProfile? soil)
    {
        var summary = new List<string>();

        var season = climate.GrowingSeasonMonths;
        if (season.Count == 12)
        {
            summary.Add("Sezon wegetacyjny: cały rok.");
        }
        else if (season.Count > 0)
        {
            summary.Add(
                $"Sezon wegetacyjny: {PolishMonths.Nominative[season[0] - 1]}–{PolishMonths.Nominative[season[^1] - 1]} (~{climate.GrowingSeasonDays} dni).");
        }
        else if (climate.AvgTempC.Any(t => t.HasValue))
        {
            summary.Add("Żaden miesiąc nie ma średniej temperatury powyżej 5 °C – bardzo krótki sezon wegetacyjny.");
        }

        if (climate.FrostRiskMonths.Count == 12)
        {
            summary.Add("Przymrozki możliwe przez cały rok.");
        }
        else if (climate.LastSpringFrostMonth is { } spring && climate.FirstAutumnFrostMonth is { } autumn)
        {
            summary.Add($"Przymrozki możliwe do {PolishMonths.Genitive[spring - 1]} i od {PolishMonths.Genitive[autumn - 1]}.");
        }
        else if (climate.LastSpringFrostMonth is { } springOnly)
        {
            summary.Add($"Przymrozki możliwe do {PolishMonths.Genitive[springOnly - 1]}.");
        }
        else if (climate.FirstAutumnFrostMonth is { } autumnOnly)
        {
            summary.Add($"Przymrozki możliwe od {PolishMonths.Genitive[autumnOnly - 1]}.");
        }
        else if (climate.MinTempC.Any(t => t.HasValue))
        {
            summary.Add("W danych z wielolecia nie notowano przymrozków.");
        }

        if (climate.AnnualPrecipitationMm is { } annual)
        {
            var text = $"Opady: {Math.Round(annual, MidpointRounding.AwayFromZero):0} mm/rok";
            if (climate.SeasonPrecipitationMm is { } inSeason)
            {
                text += $", {Math.Round(inSeason, MidpointRounding.AwayFromZero):0} mm w sezonie (IV–IX)";
            }

            summary.Add(text + ".");
        }

        if (climate.HeatRiskMonths.Count > 0)
        {
            summary.Add($"Upały powyżej 30 °C notowano {PolishMonths.InList(climate.HeatRiskMonths)}.");
        }

        if (climate.DryMonths.Count is > 0 and < 12 && climate.SoilMoistureDropPct is { } drop and > 0)
        {
            summary.Add($"Gleba wysycha {PolishMonths.InList(climate.DryMonths)} (wilgotność −{drop}%).");
        }

        if (soil is not null)
        {
            var parts = new List<string>();
            if (soil.SoilClass is { } soilClass)
            {
                parts.Add($"Gleba {soilClass.ToLowerInvariant()}");
                if (soilClass == "Lekka") parts.Add("piaszczysta");
                if (soilClass == "Ciężka") parts.Add("gliniasta");
            }
            else
            {
                parts.Add("Gleba");
            }

            if (soil.PhClass is { } phClass)
            {
                parts.Add(phClass.ToLowerInvariant());
            }

            var comment = soil.SoilClass switch
            {
                "Lekka" => " – słabo zatrzymuje wodę.",
                "Ciężka" => " – dobrze zatrzymuje wodę, ale wolno się nagrzewa.",
                _ => ".",
            };

            if (parts.Count > 1)
            {
                summary.Add(string.Join(", ", parts) + comment);
            }

            // Only problems get a sentence, to keep the summary short.
            if (soil.NitrogenClass == "Niska")
            {
                summary.Add("Mało azotu w glebie – rośliny bobowate (np. groch, łubin, koniczyna) mogą go uzupełnić.");
            }

            if (soil.CecClass == "Niska")
            {
                summary.Add("Gleba słabo zatrzymuje składniki pokarmowe – nawozy łatwo się wymywają, pomagają międzyplony.");
            }

            if (soil.CompactionClass == "Zagęszczona")
            {
                summary.Add("Gleba może być zbita – pomagają rośliny o głębokich korzeniach (np. rzodkiew oleista, lucerna).");
            }

            if (soil.StoneClass == "Duża")
            {
                summary.Add("Dużo kamieni w glebie – utrudnia uprawę ziemniaków i buraków.");
            }
        }

        return summary;
    }

    // ---------------------------------------------------------------- helpers

    /// <summary>1-based months whose value is present and matches the predicate.</summary>
    private static List<int> MonthsWhere(IReadOnlyList<double?> values, Func<double, bool> predicate)
    {
        var months = new List<int>();
        for (var i = 0; i < values.Count; i++)
        {
            if (values[i] is { } v && predicate(v))
            {
                months.Add(i + 1);
            }
        }

        return months;
    }

    private static double? SumOrNull(IEnumerable<double?> values)
    {
        var present = values.OfType<double>().ToList();
        return present.Count > 0 ? Round(present.Sum(), 1) : null;
    }

    private static double Round(double value, int digits) => Math.Round(value, digits, MidpointRounding.AwayFromZero);

    private static double? RoundOrNull(double? value, int digits) => value is { } v ? Round(v, digits) : null;
}
