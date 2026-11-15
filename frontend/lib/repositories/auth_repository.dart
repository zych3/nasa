import 'dart:async';

import '../api/api_client.dart';
import '../models/account.dart';

/// Sign-up and sign-in against the backend (`/api/auth/...`).
/// Every failure becomes an [AuthException] with a reason the screen can show.
class AuthRepository {
  AuthRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.shared;

  final ApiClient _api;

  static const _timeout = Duration(seconds: 15);

  Future<AccountSession> register({
    required String email,
    required String password,
    String? name,
  }) => _session(
    () => _api.postJson('/api/auth/register', {
      'email': email,
      'password': password,
      'name': ?name,
    }, timeout: _timeout),
  );

  Future<AccountSession> login({
    required String email,
    required String password,
  }) => _session(
    () => _api.postJson('/api/auth/login', {
      'email': email,
      'password': password,
    }, timeout: _timeout),
  );

  /// The user of [token]. Throws [AuthException] with
  /// [AuthError.invalidCredentials] when the token is no longer valid.
  Future<AccountUser> me(String token) => _guard(() async {
    final json = await _api.getJson(
      '/api/auth/me',
      authToken: token,
      timeout: _timeout,
    );
    return AccountUser.fromJson(json as Map<String, dynamic>);
  });

  /// Ends the session on the server. Failures are ignored: the device forgets
  /// the token anyway.
  Future<void> logout(String token) async {
    try {
      await _api.postJson(
        '/api/auth/logout',
        const {},
        authToken: token,
        timeout: _timeout,
      );
    } catch (_) {
      // Nothing to tell the user: they are signed out on this device.
    }
  }

  Future<AccountSession> _session(Future<dynamic> Function() call) =>
      _guard(() async {
        final json = await call();
        return AccountSession.fromJson(json as Map<String, dynamic>);
      });

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw AuthException(AuthError.fromCode(e.code, e.statusCode));
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(AuthError.noConnection);
    } catch (_) {
      // Socket / HTTP client errors: the backend cannot be reached.
      throw const AuthException(AuthError.noConnection);
    }
  }
}
