import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';

/// Source of `GET /api/map-layers` for the overlays. Screens use this (through
/// `OverlayController`), never [ApiClient].
///
/// One response holds every overlay of a place, so it is fetched once per
/// place and kept for the session: switching overlays needs no new request.
class MapLayersRepository {
  MapLayersRepository({ApiClient? apiClient, this.useMock = false})
    : _api = apiClient ?? ApiClient.shared;

  /// Saved real response for lat 52.20, lon 21.48 (demo / offline data).
  static const mockAsset = 'assets/mock/map_layers_sample.json';

  /// Places kept in memory (each response is ~16 kB of JSON).
  static const maxCachedPlaces = 20;

  /// The first request for a place takes 5–10 s (the backend asks NASA POWER
  /// and SoilGrids), more when NASA is slow. Giving up earlier would also
  /// cancel the backend's work, so "Try again" would start from zero.
  static const timeout = Duration(seconds: 40);

  final ApiClient _api;

  /// Always answer with the demo data instead of calling the backend.
  final bool useMock;

  /// Finished and in-flight requests, oldest first (map literals keep the
  /// insertion order). A failed request is removed, so the next call tries
  /// again.
  final _cache = <String, Future<Map<String, dynamic>>>{};

  /// The backend rounds the point to 2 decimal places (~1 km), so points that
  /// round the same share one response.
  static String _cacheKey(LatLng point) =>
      '${point.latitude.toStringAsFixed(2)},${point.longitude.toStringAsFixed(2)}';

  /// Layers for [point]. With [refresh] the cached response is dropped first.
  ///
  /// Throws [ApiException] (HTTP error, e.g. 502 when NASA POWER is down),
  /// `TimeoutException` / `ClientException` (no connection) or
  /// [FormatException] (the body is not a JSON object).
  Future<Map<String, dynamic>> mapLayers(LatLng point, {bool refresh = false}) {
    if (useMock) return demo();

    final key = _cacheKey(point);
    if (refresh) _cache.remove(key);
    final cached = _cache[key];
    if (cached != null) return cached;

    final future = _fetch(point);
    _cache[key] = future;
    while (_cache.length > maxCachedPlaces) {
      _cache.remove(_cache.keys.first);
    }
    // Forget failures so "Try again" really asks the backend again.
    future.catchError((Object _) {
      if (identical(_cache[key], future)) _cache.remove(key);
      return const <String, dynamic>{};
    });
    return future;
  }

  /// The saved demo response (always the same place, see [mockAsset]).
  Future<Map<String, dynamic>> demo() async =>
      _asObject(jsonDecode(await rootBundle.loadString(mockAsset)));

  Future<Map<String, dynamic>> _fetch(LatLng point) async => _asObject(
    await _api.getJson(
      '/api/map-layers',
      query: {
        'lat': point.latitude.toStringAsFixed(5),
        'lon': point.longitude.toStringAsFixed(5),
      },
      timeout: timeout,
    ),
  );

  static Map<String, dynamic> _asObject(Object? json) {
    if (json is Map<String, dynamic>) return json;
    throw const FormatException('map-layers: response is not a JSON object');
  }
}
