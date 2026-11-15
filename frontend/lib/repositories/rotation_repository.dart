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
}
