namespace FieldShift.Web.DTOs;

/// <summary>Merged climate + soil profile of a field, built from NASA POWER and ISRIC SoilGrids.</summary>
public sealed record FieldProfileResponse
{
    /// <summary>Location the profile was computed for (coordinates rounded to 2 decimal places).</summary>
    public required LocationInfo Location { get; init; }

    /// <summary>Long-term climate of the location (NASA POWER climatology).</summary>
    public required ClimateProfile Climate { get; init; }

    /// <summary>Topsoil (0–30 cm) properties from SoilGrids; null when unavailable (built-up area, water, service error).</summary>
    public SoilProfile? Soil { get; init; }

    /// <summary>Short plain-language sentences (Polish) describing the field, generated from the values above.</summary>
    public required IReadOnlyList<string> Summary { get; init; }

    /// <summary>Data quality warnings (Polish), e.g. missing data or values that were skipped.</summary>
    public required IReadOnlyList<string> Warnings { get; init; }

    /// <summary>Disclaimer (Polish): the data supports the farmer's decision but does not replace it.</summary>
    public required string Disclaimer { get; init; }

    /// <summary>When this profile was generated (UTC, ISO 8601).</summary>
    public required DateTimeOffset GeneratedAtUtc { get; init; }
}

/// <summary>Point location of the field.</summary>
public sealed record LocationInfo
{
    /// <summary>Latitude in decimal degrees (WGS84), −90…90.</summary>
    public required double Lat { get; init; }

    /// <summary>Longitude in decimal degrees (WGS84), −180…180.</summary>
    public required double Lon { get; init; }

    /// <summary>Elevation above sea level in metres (from NASA POWER, grid-cell average); null if unknown.</summary>
    public int? ElevationM { get; init; }
}

/// <summary>Long-term monthly climate. All 12-element arrays are indexed 0 = January … 11 = December; null = no data.</summary>
public sealed record ClimateProfile
{
    /// <summary>Data source and period (Polish), e.g. "NASA POWER, klimatologia 2001–2025 (siatka MERRA-2 ~50 km)".</summary>
    public required string Source { get; init; }

    /// <summary>What these numbers mean (Polish).</summary>
    public required string Description { get; init; }

    /// <summary>Mean monthly air temperature at 2 m, °C (NASA POWER T2M).</summary>
    public required IReadOnlyList<double?> AvgTempC { get; init; }

    /// <summary>Lowest temperature recorded in each month over the whole period (a record, not an average), °C (T2M_MIN).</summary>
    public required IReadOnlyList<double?> MinTempC { get; init; }

    /// <summary>Highest temperature recorded in each month over the whole period (a record, not an average), °C (T2M_MAX).</summary>
    public required IReadOnlyList<double?> MaxTempC { get; init; }

    /// <summary>Mean monthly precipitation total, mm/month (PRECTOTCORR mm/day × days in month, February = 28).</summary>
    public required IReadOnlyList<double?> PrecipitationMm { get; init; }

    /// <summary>Root-zone soil wetness, unitless 0–1 (0 = dry, 1 = saturated) (GWETROOT).</summary>
    public required IReadOnlyList<double?> SoilMoisture { get; init; }

    /// <summary>Months (1–12) with mean temperature above 5 °C.</summary>
    public required IReadOnlyList<int> GrowingSeasonMonths { get; init; }

    /// <summary>Total number of days in the growing-season months, days.</summary>
    public required int GrowingSeasonDays { get; init; }

    /// <summary>Mean annual precipitation, mm/year; null if no data.</summary>
    public double? AnnualPrecipitationMm { get; init; }

    /// <summary>Mean precipitation from April to September, mm; null if no data.</summary>
    public double? SeasonPrecipitationMm { get; init; }

    /// <summary>Months (1–12) in which frost (below 0 °C) has been recorded.</summary>
    public required IReadOnlyList<int> FrostRiskMonths { get; init; }

    /// <summary>Latest month in January–June with recorded frost (1–6); null if none.</summary>
    public int? LastSpringFrostMonth { get; init; }

    /// <summary>Earliest month in July–December with recorded frost (7–12); null if none.</summary>
    public int? FirstAutumnFrostMonth { get; init; }

    /// <summary>Months (1–12) in which temperatures above 30 °C have been recorded.</summary>
    public required IReadOnlyList<int> HeatRiskMonths { get; init; }

    /// <summary>Months (1–12) with the driest soil (root-zone wetness within 0.01 of the yearly minimum).</summary>
    public required IReadOnlyList<int> DryMonths { get; init; }

    /// <summary>How much root-zone wetness drops from the wettest to the driest month, % of the maximum; null if no data.</summary>
    public int? SoilMoistureDropPct { get; init; }
}

/// <summary>Topsoil (0–30 cm, thickness-weighted average) properties estimated by the SoilGrids model.</summary>
public sealed record SoilProfile
{
    /// <summary>Data source (Polish).</summary>
    public required string Source { get; init; }

    /// <summary>What these numbers mean (Polish).</summary>
    public required string Description { get; init; }

    /// <summary>Sand content, % by mass; null if no data.</summary>
    public double? SandPct { get; init; }

    /// <summary>Clay content, % by mass; null if no data.</summary>
    public double? ClayPct { get; init; }

    /// <summary>Silt content, % by mass; null if no data.</summary>
    public double? SiltPct { get; init; }

    /// <summary>Soil pH measured in water, pH units; null if no data.</summary>
    public double? Ph { get; init; }

    /// <summary>Soil organic carbon, g/kg; null if no data.</summary>
    public double? OrganicCarbonGkg { get; init; }

    /// <summary>Total nitrogen, g/kg; null if no data.</summary>
    public double? NitrogenGkg { get; init; }

    /// <summary>Cation exchange capacity at pH 7 (how well soil holds nutrients), cmol(c)/kg; null if no data.</summary>
    public double? CecCmolKg { get; init; }

    /// <summary>Bulk density of the fine earth, g/cm³ (= kg/dm³); null if no data.</summary>
    public double? BulkDensityGcm3 { get; init; }

    /// <summary>Coarse fragments (stones, gravel), % by volume; null if no data.</summary>
    public double? CoarseFragmentsPct { get; init; }

    /// <summary>Soil heaviness class (Polish): "Lekka" (sand &gt; 65%), "Ciężka" (clay &gt; 30%), otherwise "Średnia".</summary>
    public string? SoilClass { get; init; }

    /// <summary>Acidity class (Polish): "Kwaśna" (&lt; 5.5), "Lekko kwaśna" (5.5–6.5), "Obojętna" (6.5–7.2), "Zasadowa" (&gt; 7.2).</summary>
    public string? PhClass { get; init; }

    /// <summary>Organic matter class (Polish) from organic carbon: "Niska" (&lt; 10 g/kg), "Średnia" (10–20), "Wysoka" (&gt; 20).</summary>
    public string? OrganicMatterClass { get; init; }

    /// <summary>Nitrogen class (Polish), approximate: "Niska" (&lt; 1 g/kg), "Średnia" (1–2), "Wysoka" (&gt; 2).</summary>
    public string? NitrogenClass { get; init; }

    /// <summary>Nutrient-holding class (Polish) from CEC: "Niska" (&lt; 10 cmol(c)/kg), "Średnia" (10–20), "Wysoka" (&gt; 20).</summary>
    public string? CecClass { get; init; }

    /// <summary>Compaction class (Polish) from bulk density, threshold depends on soil class
    /// (Lekka &gt; 1.60, Średnia &gt; 1.50, Ciężka &gt; 1.40 g/cm³): "Zagęszczona" or "Prawidłowa".</summary>
    public string? CompactionClass { get; init; }

    /// <summary>Stoniness class (Polish) from coarse fragments: "Mała" (&lt; 5%), "Średnia" (5–15%), "Duża" (&gt; 15%).</summary>
    public string? StoneClass { get; init; }
}
