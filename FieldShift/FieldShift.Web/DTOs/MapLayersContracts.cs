namespace FieldShift.Web.DTOs;

/// <summary>Monthly time series of climate and soil map layers for one point, ready to draw with a date slider.</summary>
public sealed record MapLayersResponse
{
    /// <summary>Point the layers were computed for (coordinates rounded to 2 decimal places).</summary>
    public required MapLocation Location { get; init; }

    /// <summary>First and last month of the series (inclusive).</summary>
    public required MapPeriod Period { get; init; }

    /// <summary>Time step of the series; always "month".</summary>
    public required string Granularity { get; init; }

    /// <summary>Months of the series, "yyyy-MM", ascending. Every <c>values</c> array has exactly this length.</summary>
    public required IReadOnlyList<string> Dates { get; init; }

    /// <summary>Layer to show first ("soilMoisture" when requested, otherwise the first returned layer).</summary>
    public required string DefaultLayerId { get; init; }

    /// <summary>Index into <c>dates</c> where the slider starts: the latest month.</summary>
    public required int DefaultIndex { get; init; }

    /// <summary>Requested layers with data, sorted by <c>order</c>.</summary>
    public required IReadOnlyList<LayerSeries> Layers { get; init; }

    /// <summary>Data that does not change over time (soil, terrain).</summary>
    public required StaticLayers Static { get; init; }

    /// <summary>Data quality notes (Polish) to show to the user.</summary>
    public required IReadOnlyList<string> Warnings { get; init; }

    /// <summary>When this response was generated (UTC, ISO 8601).</summary>
    public required DateTimeOffset GeneratedAtUtc { get; init; }
}

/// <summary>Point location.</summary>
public sealed record MapLocation
{
    /// <summary>Latitude in decimal degrees (WGS84), −90…90.</summary>
    public required double Lat { get; init; }

    /// <summary>Longitude in decimal degrees (WGS84), −180…180.</summary>
    public required double Lon { get; init; }
}

/// <summary>Inclusive month range.</summary>
public sealed record MapPeriod
{
    /// <summary>First month, "yyyy-MM".</summary>
    public required string From { get; init; }

    /// <summary>Last month, "yyyy-MM".</summary>
    public required string To { get; init; }
}

/// <summary>Static description of a layer (no data). Returned by <c>/api/map-layers/definitions</c>.</summary>
public sealed record LayerDefinitionDto
{
    /// <summary>Layer id, e.g. "precipitation". Use it in the <c>layers</c> query parameter.</summary>
    public required string Id { get; init; }

    /// <summary>Display name (Polish).</summary>
    public required string Name { get; init; }

    /// <summary>Unit of <c>values</c>, e.g. "mm", "°C", "dni", "0–1", "0–100".</summary>
    public required string Unit { get; init; }

    /// <summary>Group for the layer switcher (Polish): "Klimat", "Woda" or "Rośliny i gleba".</summary>
    public required string Group { get; init; }

    /// <summary>Sort order in the layer switcher, 1 = first.</summary>
    public required int Order { get; init; }

    /// <summary>Number of decimal places the values are rounded to (format with the same precision).</summary>
    public required int Decimals { get; init; }

    /// <summary>True for derived estimates (not measured); show them with an "estimate" label.</summary>
    public required bool IsEstimate { get; init; }

    /// <summary>Data source, e.g. "NASA POWER (PRECTOTCORR)".</summary>
    public required string Source { get; init; }

    /// <summary>One sentence (Polish): what the value means and how to read it.</summary>
    public required string Description { get; init; }

    /// <summary>Colour scale for <c>values</c>.</summary>
    public required Legend Legend { get; init; }

    /// <summary>Colour scale for <c>anomalies</c>; null for layers without anomalies.</summary>
    public Legend? AnomalyLegend { get; init; }
}

/// <summary>One layer with its monthly series.</summary>
public sealed record LayerSeries
{
    /// <summary>Layer id, e.g. "precipitation".</summary>
    public required string Id { get; init; }

    /// <summary>Display name (Polish).</summary>
    public required string Name { get; init; }

    /// <summary>Unit of <c>values</c>.</summary>
    public required string Unit { get; init; }

    /// <summary>Group for the layer switcher (Polish).</summary>
    public required string Group { get; init; }

    /// <summary>Sort order in the layer switcher, 1 = first.</summary>
    public required int Order { get; init; }

    /// <summary>Number of decimal places the values are rounded to.</summary>
    public required int Decimals { get; init; }

    /// <summary>True for derived estimates (not measured).</summary>
    public required bool IsEstimate { get; init; }

    /// <summary>Data source.</summary>
    public required string Source { get; init; }

    /// <summary>One sentence (Polish): what the value means and how to read it.</summary>
    public required string Description { get; init; }

    /// <summary>Monthly values in <c>unit</c>, same length and order as <c>dates</c>; null = no data for that month.</summary>
    public required IReadOnlyList<double?> Values { get; init; }

    /// <summary>
    /// Only for temperature, precipitation and soilMoisture: value minus the mean of the same calendar month over the
    /// whole period, in <c>unit</c> (positive = warmer / wetter than usual). Null for other layers.
    /// </summary>
    public IReadOnlyList<double?>? Anomalies { get; init; }

    /// <summary>
    /// Extra monthly series, same length as <c>dates</c>. temperature: "max" / "min" (highest daily max / lowest
    /// daily min, °C); extremeRain: "maxDailyMm" (highest daily rainfall, mm). Null for other layers.
    /// </summary>
    public IReadOnlyDictionary<string, IReadOnlyList<double?>>? Extra { get; init; }

    /// <summary>Colour scale for <c>values</c>.</summary>
    public required Legend Legend { get; init; }

    /// <summary>Colour scale for <c>anomalies</c>; null for layers without anomalies.</summary>
    public Legend? AnomalyLegend { get; init; }

    /// <summary>Summary statistics of <c>values</c> over the whole period.</summary>
    public required LayerStats Stats { get; init; }
}

/// <summary>Summary statistics of a layer, in the layer's unit.</summary>
public sealed record LayerStats
{
    /// <summary>Lowest monthly value; null if no data.</summary>
    public double? Min { get; init; }

    /// <summary>Highest monthly value; null if no data.</summary>
    public double? Max { get; init; }

    /// <summary>Mean of the monthly values; null if no data.</summary>
    public double? Mean { get; init; }

    /// <summary>
    /// Linear trend of yearly values (yearly mean for temperature, soilMoisture, plantStress, erosionRisk; yearly sum
    /// for the other layers) in unit per 10 years. Only complete years count; null with fewer than 2 complete years.
    /// </summary>
    public double? TrendPerDecade { get; init; }
}

/// <summary>Colour scale. A value belongs to the first stop where <c>value &lt; max</c>; the last stop has <c>max = null</c>.</summary>
public sealed record Legend
{
    /// <summary>"sequential" (low → high) or "diverging" (below normal ← normal → above normal).</summary>
    public required string Type { get; init; }

    /// <summary>Stops sorted by <c>max</c> ascending; the last one has <c>max = null</c> (no upper bound).</summary>
    public required IReadOnlyList<LegendStop> Stops { get; init; }
}

/// <summary>One colour band of a legend.</summary>
public sealed record LegendStop
{
    /// <summary>Exclusive upper bound in the layer's unit; null for the last stop.</summary>
    public double? Max { get; init; }

    /// <summary>Colour, "#RRGGBB".</summary>
    public required string Color { get; init; }

    /// <summary>Label with the range (Polish), e.g. "sucho (20–40 mm)".</summary>
    public required string Label { get; init; }
}

/// <summary>Layers that do not change over time.</summary>
public sealed record StaticLayers
{
    /// <summary>Topsoil summary from SoilGrids; null if unavailable.</summary>
    public MapSoil? Soil { get; init; }

    /// <summary>Terrain slope from pre-computed demo locations; null if this point has no slope data.</summary>
    public MapTerrain? Terrain { get; init; }
}

/// <summary>Topsoil (0–30 cm) summary.</summary>
public sealed record MapSoil
{
    /// <summary>Data source.</summary>
    public required string Source { get; init; }

    /// <summary>Soil heaviness class (Polish): "Lekka", "Średnia" or "Ciężka"; null if unknown.</summary>
    public string? SoilClass { get; init; }

    /// <summary>Sand content, % by mass.</summary>
    public double? SandPct { get; init; }

    /// <summary>Clay content, % by mass.</summary>
    public double? ClayPct { get; init; }

    /// <summary>Soil pH in water.</summary>
    public double? Ph { get; init; }
}

/// <summary>Terrain slope.</summary>
public sealed record MapTerrain
{
    /// <summary>Data source.</summary>
    public required string Source { get; init; }

    /// <summary>Mean terrain slope, %.</summary>
    public required double SlopePct { get; init; }

    /// <summary>Slope class (Polish): "płasko" (&lt; 2%), "łagodny spadek" (2–6%), "umiarkowany spadek" (6–12%), "stromo" (&gt; 12%).</summary>
    public required string SlopeClass { get; init; }
}

/// <summary>
/// Monthly layers for a block of NASA POWER grid cells around a point (<c>/api/map-layers/grid</c>), for drawing
/// the area around a field as a heat map. Each cell has one value per month, the same as <c>/api/map-layers</c>
/// returns for any point inside that cell.
/// </summary>
public sealed record MapLayersGridResponse
{
    /// <summary>Centre of the grid cell that contains the requested point (the middle cell).</summary>
    public required MapLocation Center { get; init; }

    /// <summary>Size of one cell in degrees: 0.5° latitude × 0.625° longitude (NASA POWER / MERRA-2).</summary>
    public required GridCellSize CellSize { get; init; }

    /// <summary>Number of rows (south → north) and columns (west → east) of the block.</summary>
    public required int Rows { get; init; }

    /// <inheritdoc cref="Rows"/>
    public required int Cols { get; init; }

    /// <summary>First and last month of the series (inclusive).</summary>
    public required MapPeriod Period { get; init; }

    /// <summary>Months of the series, "yyyy-MM", ascending. Every series in <c>layers[].values</c> has this length.</summary>
    public required IReadOnlyList<string> Dates { get; init; }

    /// <summary>Index into <c>dates</c> of the latest month.</summary>
    public required int DefaultIndex { get; init; }

    /// <summary>Cells of the block. Cells outside the globe (near the poles or the date line) are left out.</summary>
    public required IReadOnlyList<GridCell> Cells { get; init; }

    /// <summary>Requested layers, sorted by <c>order</c>.</summary>
    public required IReadOnlyList<GridLayer> Layers { get; init; }

    /// <summary>Data quality notes (Polish) to show to the user.</summary>
    public required IReadOnlyList<string> Warnings { get; init; }

    /// <summary>When this response was generated (UTC, ISO 8601).</summary>
    public required DateTimeOffset GeneratedAtUtc { get; init; }
}

/// <summary>Size of a grid cell in degrees.</summary>
public sealed record GridCellSize
{
    /// <summary>Height in degrees of latitude.</summary>
    public required double Lat { get; init; }

    /// <summary>Width in degrees of longitude.</summary>
    public required double Lon { get; init; }
}

/// <summary>One grid cell: its place in the block and its centre.</summary>
public sealed record GridCell
{
    /// <summary>Row, 0 = southernmost.</summary>
    public required int Row { get; init; }

    /// <summary>Column, 0 = westernmost.</summary>
    public required int Col { get; init; }

    /// <summary>Latitude of the cell centre.</summary>
    public required double Lat { get; init; }

    /// <summary>Longitude of the cell centre.</summary>
    public required double Lon { get; init; }
}

/// <summary>One layer over the whole block.</summary>
public sealed record GridLayer
{
    /// <summary>Layer id, e.g. "precipitation".</summary>
    public required string Id { get; init; }

    /// <summary>Display name (Polish).</summary>
    public required string Name { get; init; }

    /// <summary>Unit of the values.</summary>
    public required string Unit { get; init; }

    /// <summary>Number of decimal places the values are rounded to.</summary>
    public required int Decimals { get; init; }

    /// <summary>True for derived estimates (not measured).</summary>
    public required bool IsEstimate { get; init; }

    /// <summary>Data source.</summary>
    public required string Source { get; init; }

    /// <summary>Colour scale for the values (the same as in <c>/api/map-layers</c>).</summary>
    public required Legend Legend { get; init; }

    /// <summary>
    /// One monthly series per cell, in the order of <c>cells</c>; each has the length of <c>dates</c>. Null = no
    /// data for that month; a cell NASA POWER did not answer for has only nulls.
    /// </summary>
    public required IReadOnlyList<IReadOnlyList<double?>> Values { get; init; }
}
