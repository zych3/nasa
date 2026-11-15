import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/overlays/map_layers_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient slowClient(Duration delay) => ApiClient(
    baseUrl: 'http://test',
    httpClient: MockClient((_) async {
      await Future<void>.delayed(delay);
      return http.Response('{}', 200);
    }),
  );

  test('gives up after the given timeout', () async {
    await expectLater(
      slowClient(const Duration(milliseconds: 200))
          .getJson('/slow', timeout: const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('waits longer than the default when asked to', () async {
    final json = await slowClient(const Duration(milliseconds: 20))
        .getJson('/slow', timeout: const Duration(seconds: 1));
    expect(json, isEmpty);
  });

  test('map layers wait longer than the default limit', () {
    expect(MapLayersRepository.timeout, greaterThan(ApiClient.defaultTimeout));
  });
}
