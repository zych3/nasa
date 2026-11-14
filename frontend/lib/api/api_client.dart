import 'dart:convert';

import 'package:http/http.dart' as http;

/// Backend base URL.
/// - desktop / web: http://localhost:5066
/// - Android emulator: http://10.0.2.2:5066
/// - real phone: `http://<computer LAN IP>:5066`
const String apiBaseUrl = 'http://localhost:5066';

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

  final http.Client _http;
  final String baseUrl;

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    String? languageCode,
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
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException(
        'GET $path failed with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
