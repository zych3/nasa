import '../api/api_client.dart';
import '../models/frost_risk.dart';

/// Frost forecast for a point, from our backend.
class FrostRiskRepository {
  FrostRiskRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;

  Future<FrostRisk> at(double latitude, double longitude) async {
    final json = await _api.getJson(
      '/api/weather/frost-risk',
      query: {'lat': '$latitude', 'lon': '$longitude'},
    );
    return FrostRisk.fromJson(json as Map<String, dynamic>);
  }
}
