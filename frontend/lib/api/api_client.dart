import 'dart:convert';

import 'package:http/http.dart' as http;

/// Backend base URL.
/// - desktop / web: http://localhost:5066
/// - Android emulator: http://10.0.2.2:5066
/// - real phone: `http://<computer LAN IP>:5066`
/// Override at build time with `--dart-define=API_BASE_URL=...` (used by the Docker image).
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5066',
);

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;

  /// Error code from the body (`{"code": "username_taken"}`), when the backend
  /// sent one. The app maps codes to its own words; never show it raw.
  final String? code;

  @override
  String toString() => 'ApiException: $message';
}

/// The only place in the app that does HTTP.
class ApiClient {
  ApiClient({http.Client? httpClient, this.baseUrl = apiBaseUrl})
    : _http = httpClient ?? http.Client();

  /// One client for the whole app, used by the repositories by default, so
  /// requests share connections (each price badge used to open its own).
  static final ApiClient shared = ApiClient();

  final http.Client _http;
  final String baseUrl;

  /// Default limit for one request.
  static const defaultTimeout = Duration(seconds: 15);

  /// GET [path] and decode the JSON body. Throws [ApiException] for a status
  /// other than 200 and `TimeoutException` after [timeout].
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    String? languageCode,
    String? authToken,
    Duration timeout = defaultTimeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': ?languageCode,
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        )
        .timeout(timeout);

    return _decode('GET', path, response);
  }

  /// POST with a JSON body. Calculations can take a while (the backend may
  /// have to ask NASA and SoilGrids first), hence the long timeout.
  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    String? languageCode,
    String? authToken,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final response = await _http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Accept-Language': ?languageCode,
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    return _decode('POST', path, response);
  }

  /// The decoded body of a 2xx answer (`null` when empty, e.g. 204).
  /// Otherwise throws [ApiException] with the body's error `code`, if any.
  static dynamic _decode(String method, String path, http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    final text = utf8.decode(response.bodyBytes);
    if (ok) return text.isEmpty ? null : jsonDecode(text);

    String? code;
    try {
      final body = jsonDecode(text);
      if (body is Map<String, dynamic> && body['code'] is String) {
        code = body['code'] as String;
      }
    } catch (_) {
      // Not JSON (e.g. a proxy error page): no code.
    }
    throw ApiException(
      '$method $path failed with ${response.statusCode}',
      statusCode: response.statusCode,
      code: code,
    );
  }
}
