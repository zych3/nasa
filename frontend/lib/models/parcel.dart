import 'package:latlong2/latlong.dart';

class Parcel {
  const Parcel({
    required this.id,
    required this.center,
    required this.ring,
    this.address,
    this.distanceMeters,
  });

  final String id;
  final LatLng center;

  /// Outer boundary of the parcel (closed ring).
  final List<LatLng> ring;

  /// Human-readable address (typed by the user or from the nearest address point).
  final String? address;

  /// Distance from the point the parcel was searched around (nearby lookup only).
  final double? distanceMeters;

  Parcel withAddress(String? address) => Parcel(
    id: id,
    center: center,
    ring: ring,
    address: address,
    distanceMeters: distanceMeters,
  );

  factory Parcel.fromJson(Map<String, dynamic> json) => Parcel(
    id: json['parcelId'] as String,
    center: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    ring: parseEwkt(json['geometryWkt'] as String),
    address: json['address'] as String?,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'parcelId': id,
    'latitude': center.latitude,
    'longitude': center.longitude,
    'geometryWkt': toEwkt(ring),
    'address': ?address,
    'distanceMeters': ?distanceMeters,
  };
}

/// Parses `SRID=4326;POLYGON((lon lat,lon lat,...))` into the outer ring.
/// WKT is `lon lat`, [LatLng] is (lat, lon) - hence the swap.
/// Holes and MultiPolygon are not supported (only the first ring is read).
List<LatLng> parseEwkt(String ewkt) {
  final start = ewkt.indexOf('((');
  final end = ewkt.indexOf(')', start + 2);
  if (!ewkt.contains('POLYGON') || start < 0 || end < 0) {
    throw FormatException('Unsupported geometry: $ewkt');
  }

  return [
    for (final pair in ewkt.substring(start + 2, end).split(','))
      _toLatLng(pair.trim().split(RegExp(r'\s+'))),
  ];
}

/// Inverse of [parseEwkt].
String toEwkt(List<LatLng> ring) =>
    'SRID=4326;POLYGON((${ring.map((p) => '${p.longitude} ${p.latitude}').join(',')}))';

LatLng _toLatLng(List<String> xy) {
  if (xy.length < 2) throw FormatException('Bad coordinate: $xy');
  return LatLng(double.parse(xy[1]), double.parse(xy[0]));
}
