import '../api/api_client.dart';
import '../models/rotation_report.dart';

class RotationRepository {
  RotationRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<RotationReport> getReport({
    required String? parcelId,
    required double lat,
    required double lon,
    required RotationAnswers answers,
  }) async {
    final json = await _api.postJson(
      '/api/recommendations',
      answers.toJson(parcelId: parcelId, lat: lat, lon: lon),
    );
    return RotationReport.fromJson(json as Map<String, dynamic>);
  }

  /// Keeps [plan] in the signed-in user's profile (`POST /api/me/plans`).
  /// Throws [ApiException]: `statusCode` 401 when the token is no longer
  /// valid, otherwise the backend's error `code` (e.g. `too_many_plans`).
  Future<void> savePlan({
    required String authToken,
    required String? parcelId,
    required double lat,
    required double lon,
    required String goal,
    required RotationPlan plan,
    required RotationAnswers answers,
  }) async {
    await _api.postJson('/api/me/plans', {
      'parcelId': ?parcelId,
      'lat': lat,
      'lon': lon,
      'goal': goal,
      'plan': plan.raw,
      'answers': answers.toJson(parcelId: parcelId, lat: lat, lon: lon),
    }, authToken: authToken);
  }
}
