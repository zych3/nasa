import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../api/api_client.dart';
import '../models/user_crop.dart';
import 'auth_store.dart';

/// The signed-in user's saved crops (`/api/my-crops`). Sends the token from
/// [AuthStore]; when the server says the session is over (401) the store is
/// signed out. Every failure becomes a [UserCropException].
class UserCropRepository {
  UserCropRepository({required this.auth, ApiClient? apiClient})
    : _api = apiClient ?? ApiClient.shared;

  final AuthStore auth;
  final ApiClient _api;

  static const _path = '/api/my-crops';

  /// Newest first.
  Future<List<UserCrop>> list() => _guard((token) async {
    final json = await _api.getJson(_path, authToken: token);
    return [
      for (final item in json as List)
        UserCrop.fromJson(item as Map<String, dynamic>),
    ];
  });

  Future<UserCrop> create({
    required String cropId,
    required LatLng point,
    String? parcelId,
    String? label,
    bool isActive = true,
  }) => _guard((token) async {
    final json = await _api.postJson(_path, {
      'cropId': cropId,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'parcelId': ?parcelId,
      'label': ?label,
      'isActive': isActive,
    }, authToken: token);
    return UserCrop.fromJson(json as Map<String, dynamic>);
  });

  /// Changes only the given fields. An empty [label] or [parcelId] removes it.
  Future<UserCrop> update(
    String id, {
    String? cropId,
    LatLng? point,
    String? parcelId,
    String? label,
    bool? isActive,
  }) => _guard((token) async {
    final json = await _api.patchJson('$_path/$id', {
      'cropId': ?cropId,
      if (point != null) 'latitude': point.latitude,
      if (point != null) 'longitude': point.longitude,
      'parcelId': ?parcelId,
      'label': ?label,
      'isActive': ?isActive,
    }, authToken: token);
    return UserCrop.fromJson(json as Map<String, dynamic>);
  });

  Future<T> _guard<T>(Future<T> Function(String token) call) async {
    final token = auth.token;
    if (token == null) throw const UserCropException(UserCropError.signedOut);
    try {
      return await call(token);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await auth.signOut();
        throw const UserCropException(UserCropError.signedOut);
      }
      throw UserCropException(
        e.statusCode == 400 || e.statusCode == 404
            ? UserCropError.rejected
            : UserCropError.serverUnavailable,
      );
    } on TimeoutException {
      throw const UserCropException(UserCropError.noConnection);
    } on UserCropException {
      rethrow;
    } catch (_) {
      // Socket / HTTP client errors: the backend cannot be reached.
      throw const UserCropException(UserCropError.noConnection);
    }
  }
}
