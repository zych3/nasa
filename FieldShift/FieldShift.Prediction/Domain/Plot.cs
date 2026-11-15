namespace FieldShift.Prediction.Domain;

public sealed record Plot
{
    public required GeoLocation Location { get; init; }
    public required SiteSoil Soil { get; init; }
    public required ClimateData Climate { get; init; }
    public FarmerInputs Farmer { get; init; } = new();
 
    public IReadOnlyList<HistoricSeason> History { get; init; } = [];
}
 
public readonly record struct GeoLocation(double Lat, double Lon, double ElevationM);
 
public sealed record Estimate(double Median, double? Q05 = null, double? Q95 = null)
{
    public static implicit operator Estimate(double median) => new(median);
}
 
public sealed record SiteSoil
{
    public required Estimate SandPct { get; init; }
    public required Estimate ClayPct { get; init; }
    public required Estimate SiltPct { get; init; }
 
    public required Estimate PhH2O { get; init; }
 
    public required Estimate OrganicCarbonGkg { get; init; }
    public Estimate? BulkDensityGcm3 { get; init; }
    public Estimate? CecCmolKg { get; init; }
    public string? Source { get; init; }
}
 
public sealed record ClimateData
{
    public required IReadOnlyList<ClimateYear> Years { get; init; }
 
    public ClimateNormals? Normals { get; init; }
 
    public string? Source { get; init; }
}
 
public sealed record ClimateYear(int Year, IReadOnlyList<DailyWeather> Days);
 
public readonly record struct DailyWeather(
    DateOnly Date,
    double TMinC,
    double TMaxC,
    double PrecipMm,
    double? Et0Mm = null,
    double? SnowDepthCm = null,
    double? RootZoneWetness = null);
 
public sealed record ClimateNormals
{
    public IReadOnlyList<double> AvgTempC { get; init; } = [];
    public IReadOnlyList<double> PrecipitationMm { get; init; } = [];
    public IReadOnlyList<double> RootZoneWetness { get; init; } = [];
}
 
public sealed record FarmerInputs
{
    public SoilTest? SoilTest { get; init; }
    public bool HasLivestockOrManure { get; init; }
    public bool HasIrrigation { get; init; }
    public IReadOnlyList<CropId> ExcludedCrops { get; init; } = [];
    public IReadOnlyList<CropId> PreferredCrops { get; init; } = [];
    public IReadOnlyList<Objective> Priorities { get; init; } = [];
}
 
public sealed record SoilTest
{
    public required DateOnly SampledOn { get; init; }
    public double? PhKCl { get; init; }
    public double? P2O5Mg100g { get; init; }
    public double? K2OMg100g { get; init; }
    public double? MgOMg100g { get; init; }
 
    public double? PhH2OEstimate(double offset = 0.7) => PhKCl + offset;
}
 
public enum HistorySource
{
    Farmer,
    ArimrImport,
    SatelliteInferred
}
 
public sealed record HistoricSeason
{
    public required int HarvestYear { get; init; }
    public required CropId Crop { get; init; }
    public CropId? CatchCrop { get; init; }
    public ResidueHandling? Residue { get; init; }
    public IReadOnlyList<ActionId> Actions { get; init; } = [];
    public double? YieldTHa { get; init; }
    public HistorySource Source { get; init; } = HistorySource.Farmer;
 
    public double Certainty { get; init; } = 1.0;
}
 
public sealed record PlotFeatures
{
    public required double SandPct { get; init; }
    public required double ClayPct { get; init; }
    public required double InitialPhH2O { get; init; }
    public required double InitialSocGkg { get; init; }

    public required double InitialHumusCKgHa { get; init; }

    public required double AwcMmPerM { get; init; }
 
    public required double PhBufferCaOPerUnit { get; init; }
 
    public int? PolishSoilComplex { get; init; }
}