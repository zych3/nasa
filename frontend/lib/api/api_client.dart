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
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

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
    Duration timeout = defaultTimeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': ?languageCode,
          },
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw ApiException(
        'GET $path failed with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// POST with a JSON body. Calculations can take a while (the backend may
  /// have to ask NASA and SoilGrids first), hence the long timeout.
  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    String? languageCode,
  }) async {
    final response = await _http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Accept-Language': ?languageCode,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw ApiException(
        'POST $path failed with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
