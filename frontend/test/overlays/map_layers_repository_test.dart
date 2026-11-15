import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/overlays/map_layers_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const field = LatLng(52.2, 21.48);
  late List<Uri> calls;
  late int status;
  late String body;

  MapLayersRepository repo() => MapLayersRepository(
    apiClient: ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((request) async {
        calls.add(request.url);
        return http.Response.bytes(utf8.encode(body), status);
      }),
    ),
  );

  setUp(() {
    calls = [];
    status = 200;
    body = jsonEncode(loadSample());
  });

  test('calls /api/map-layers with the point', () async {
    final json = await repo().mapLayers(field);

    expect(json['defaultLayerId'], 'soilMoisture');
    expect(calls.single.path, '/api/map-layers');
    expect(calls.single.queryParameters, {
      'lat': '52.20000',
      'lon': '21.48000',
    });
  });

  test('one request per place: cached and shared while in flight', () async {
    final r = repo();
    final a = r.mapLayers(field);
    // Same place after the backend's rounding to 2 decimal places.
    final b = r.mapLayers(const LatLng(52.2004, 21.4801));
    expect(identical(a, b), isTrue);
    await a;
    await r.mapLayers(field);
    expect(calls, hasLength(1));
  });

  test('refresh asks again', () async {
    final r = repo();
    await r.mapLayers(field);
    await r.mapLayers(field, refresh: true);
    expect(calls, hasLength(2));
  });

  test('a failed request is not cached', () async {
    final r = repo();
    status = 502;
    await expectLater(r.mapLayers(field), throwsA(isA<ApiException>()));

    status = 200;
    await r.mapLayers(field);
    expect(calls, hasLength(2));
  });

  test('a body that is not a JSON object is a FormatException', () async {
    body = '[]';
    await expectLater(repo().mapLayers(field), throwsFormatException);
  });

  test('demo data is the saved sample from assets', () async {
    final json = await MapLayersRepository(useMock: true).mapLayers(field);
    expect(json['location'], {'lat': 52.2, 'lon': 21.48});
  });

  test('keeps at most maxCachedPlaces places', () async {
    final r = repo();
    for (var i = 0; i <= MapLayersRepository.maxCachedPlaces; i++) {
      await r.mapLayers(LatLng(50 + i / 10, 20));
    }
    await r.mapLayers(const LatLng(50, 20)); // the oldest was dropped
    expect(calls, hasLength(MapLayersRepository.maxCachedPlaces + 2));
  });
}
