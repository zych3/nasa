import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/address_suggestion.dart';
import '../models/parcel.dart';

/// Source of parcels for an address. Screens use this, never [ApiClient].
class ParcelRepository {
  ParcelRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;

  /// Returns `null` when no address / parcel was found (HTTP 404).
  Future<Parcel?> searchByAddress(String address) async {
    try {
      final json = await _api.getJson(
        '/api/parcels/search',
        query: {'address': address},
      );
      return Parcel.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Address hints for partly typed [text]. Empty on any error, so typing is
  /// never interrupted.
  Future<List<AddressSuggestion>> suggest(String text) async {
    try {
      final json = await _api.getJson(
        '/api/parcels/suggest',
        query: {'q': text},
      );
      return [
        for (final item in json as List<dynamic>)
          ?AddressSuggestion.tryFromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// The parcel at a point (e.g. a chosen address hint); `null` when none.
  Future<Parcel?> parcelAt(LatLng point) async {
    try {
      final json = await _api.getJson(
        '/api/parcels/at',
        query: {'lat': '${point.latitude}', 'lon': '${point.longitude}'},
      );
      return Parcel.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Parcels around a point, nearest first. The first one (distance 0, no
  /// address) is usually the parcel at the point itself.
  Future<List<Parcel>> nearby(double latitude, double longitude) async {
    final json = await _api.getJson(
      '/api/parcels/nearby',
      query: {'lat': '$latitude', 'lon': '$longitude'},
    );
    return [
      for (final item in json as List<dynamic>)
        Parcel.fromJson(item as Map<String, dynamic>),
    ];
  }
}
