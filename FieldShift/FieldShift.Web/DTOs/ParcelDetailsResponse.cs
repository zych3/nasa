using FieldShift.Web.FieldData;

namespace FieldShift.Web.DTOs;

/// <summary>
/// What is known about one registered parcel (<c>/api/parcels/details</c>), from the field data providers of its
/// country. Every section says on its own whether it has data, so one source being down does not hide the rest.
/// </summary>
public sealed record ParcelDetailsResponse
{
    /// <summary>ISO 3166-1 alpha-2 code of the country whose register has the parcel, e.g. "PL".</summary>
    public required string CountryCode { get; init; }

    /// <summary>Parcel id in that register, e.g. "141205_2.0008.60".</summary>
    public required string ParcelId { get; init; }

    /// <summary>A point inside the parcel (WGS84).</summary>
    public required MapLocation Location { get; init; }

    /// <summary>Area of the parcel's outline, hectares (the register's own area is in <c>landRegistry</c>).</summary>
    public double? OutlineAreaHa { get; init; }

    /// <summary>Land register entry: land use and soil quality classes (Poland: EGiB).</summary>
    public required FieldDataSection<LandRegistryInfo> LandRegistry { get; init; }

    /// <summary>Agricultural soil map: suitability complex, soil type, texture (Poland: mapa glebowo-rolnicza).</summary>
    public required FieldDataSection<SoilMapInfo> SoilMap { get; init; }

    /// <summary>Elevation and slope (Poland: GUGiK terrain model, 1 m).</summary>
    public required FieldDataSection<TerrainInfo> Terrain { get; init; }

    /// <summary>Modelled topsoil composition (ISRIC SoilGrids, about 250 m, worldwide).</summary>
    public required FieldDataSection<SoilProfile> SoilProperties { get; init; }

    /// <summary>When this response was put together (UTC).</summary>
    public required DateTimeOffset GeneratedAtUtc { get; init; }
}

/// <summary>One kind of data about the parcel and where it came from.</summary>
public sealed record FieldDataSection<T> where T : class
{
    public const string Ok = "ok";
    public const string NoData = "noData";
    public const string Unavailable = "unavailable";
    public const string NotSupported = "notSupported";

    /// <summary>
    /// "ok" (data below), "noData" (the source has nothing for this parcel), "unavailable" (the source did not
    /// answer; try later) or "notSupported" (no source for this country).
    /// </summary>
    public required string Status { get; init; }

    /// <summary>The data when <see cref="Status"/> is "ok".</summary>
    public T? Data { get; init; }

    /// <summary>Id of the provider that answered, e.g. "pl.egib.v1".</summary>
    public string? Provider { get; init; }

    /// <summary>When the provider's source was asked (earlier than now when the answer is cached).</summary>
    public DateTimeOffset? FetchedAtUtc { get; init; }

    /// <summary>The answer came from the PostgreSQL cache, not from the source just now.</summary>
    public bool FromCache { get; init; }
}
