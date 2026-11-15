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

/// Saved real response of `GET /api/parcels/details?lat=52.20&lon=21.48`
/// (parcel 141205_2.0008.60: soil complex 5, classes RIVb / RIVa).
Map<String, dynamic> loadParcelSample() => jsonDecode(
  File('assets/mock/parcel_details_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Legend of the soil map tile layer, as the backend sends it (part).
const soilMapLegend = <Map<String, dynamic>>[
  {
    'code': '4',
    'name': 'kompleks żytni bardzo dobry (pszenno-żytni)',
    'color': '#FE6B00',
  },
  {'code': '5', 'name': 'kompleks żytni dobry', 'color': '#FEBE00'},
  {'code': '6', 'name': 'kompleks żytni słaby', 'color': '#FEFA00'},
];

Map<String, dynamic> soilOf(Map<String, dynamic> json) =>
    (json['static'] as Map<String, dynamic>)['soil'] as Map<String, dynamic>;
