import 'dart:convert';
import 'dart:io';

/// Saved real response of `GET /api/map-layers?lat=52.20&lon=21.48`.
const samplePath = 'assets/mock/map_layers_sample.json';

/// A fresh, mutable copy of the sample on every call.
Map<String, dynamic> loadSample() =>
    jsonDecode(File(samplePath).readAsStringSync()) as Map<String, dynamic>;

/// Saved real response of `GET /api/map-layers/grid?lat=52.20&lon=21.48`.
Map<String, dynamic> loadGridSample() => jsonDecode(
  File('assets/mock/map_layers_grid_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> soilOf(Map<String, dynamic> json) =>
    (json['static'] as Map<String, dynamic>)['soil'] as Map<String, dynamic>;
