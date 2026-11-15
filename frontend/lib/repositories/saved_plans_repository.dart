import '../api/api_client.dart';
import '../models/saved_plan.dart';

/// The signed-in user's saved rotation plans (`/api/me/plans`). Saving a plan
/// is [RotationRepository.savePlan]. Failures are [ApiException]s; a
/// `statusCode` of 401 means the token is no longer valid.
class SavedPlansRepository {
  SavedPlansRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;

  /// Newest first.
  Future<List<SavedPlan>> list(String authToken) async {
    final json = await _api.getJson(
      '/api/me/plans',
      query: {'limit': '100'},
      authToken: authToken,
    );
    return [
      for (final item in json as List)
        SavedPlan.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<void> delete(String authToken, String id) =>
      _api.delete('/api/me/plans/$id', authToken: authToken);
}
