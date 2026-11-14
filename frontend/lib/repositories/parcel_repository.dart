import '../api/api_client.dart';
import '../models/parcel.dart';

/// Source of parcels for an address. Screens use this, never [ApiClient].
class ParcelRepository {
  ParcelRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

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
}
