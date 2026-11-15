import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// Small readers for the `GET /api/map-layers` response shared by the
/// overlays. They throw [FormatException] for anything that does not match
/// the contract in `FieldShift/docs/map-layers.md`.

/// `location: {lat, lon}`: the point the backend computed the values for
/// (rounded by the backend to 2 decimal places).
LatLng readLocation(Map<String, dynamic> json) {
  final location = json['location'];
  if (location is! Map<String, dynamic>) {
    throw const FormatException('map-layers: missing "location"');
  }
  final lat = location['lat'];
  final lon = location['lon'];
  if (lat is! num || lon is! num) {
    throw FormatException('map-layers: bad location $location');
  }
  final latitude = lat.toDouble();
  final longitude = lon.toDouble();
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    throw FormatException('map-layers: location out of range $location');
  }
  return LatLng(latitude, longitude);
}

/// `static` object (soil, terrain). Required by the contract.
Map<String, dynamic> readStatic(Map<String, dynamic> json) {
  final value = json['static'];
  if (value is! Map<String, dynamic>) {
    throw const FormatException('map-layers: missing "static"');
  }
  return value;
}

/// One item of `layers` by id, or `null` when the backend did not send it
/// (e.g. evaporation is skipped when NASA POWER has no data for it).
Map<String, dynamic>? findLayer(Map<String, dynamic> json, String id) {
  final layers = json['layers'];
  if (layers is! List) {
    throw const FormatException('map-layers: missing "layers"');
  }
  for (final layer in layers) {
    if (layer is Map<String, dynamic> && layer['id'] == id) return layer;
  }
  return null;
}

/// `"#RRGGBB"` (the only colour format the backend sends).
Color readHexColor(Object? value) {
  if (value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
  }
  throw FormatException('map-layers: bad colour $value');
}
