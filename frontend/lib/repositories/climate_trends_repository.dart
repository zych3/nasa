import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_client.dart';
import '../models/climate_trends.dart';

/// Long-term climate changes in the area of a parcel, from
/// `GET /api/parcels/climate-trends`. Screens use this, never [ApiClient].
///
/// Never throws: the trends are an extra at the end of the report, so when
/// they cannot be loaded the answer is null and the section is left out.
///
/// The saved real response in `assets/mock/parcel_climate_trends.json` is
/// used only for the very parcel it was saved for (or when [useMock] is
/// true): showing one area's climate for another place would mislead.
class ClimateTrendsRepository {
  ClimateTrendsRepository({ApiClient? apiClient, this.useMock = false})
    : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;
  final bool useMock;

  static const _savedAsset = 'assets/mock/parcel_climate_trends.json';

  Future<ClimateTrends?> getTrends({
    required String? parcelId,
    required double lat,
    required double lon,
  }) async {
    if (!useMock) {
      try {
        final json = await _api.getJson(
          '/api/parcels/climate-trends',
          query: {'parcelId': ?parcelId, 'lat': '$lat', 'lon': '$lon'},
          // Many years of weather may have to be fetched first.
          timeout: const Duration(seconds: 60),
        );
        return ClimateTrends.fromJson(json as Map<String, dynamic>);
      } catch (_) {
        // Backend unreachable or the data source is down: try the saved copy.
      }
    }
    return _saved(parcelId);
  }

  Future<ClimateTrends?> _saved(String? parcelId) async {
    try {
      final raw = await rootBundle.loadString(_savedAsset);
      final saved = ClimateTrends.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return useMock || (parcelId != null && saved.parcelId == parcelId)
          ? saved
          : null;
    } catch (_) {
      return null;
    }
  }
}
