import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/models/rotation_report.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/local_plans_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _plan(String crop) => {
  'transition': <dynamic>[],
  'cycle': [
    {
      'harvestYear': 2027,
      'crop': {
        'id': crop,
        'name': {'en': crop, 'pl': crop},
      },
      'harvest': {'value': 0.8, 'level': 'good'},
    },
  ],
  'cycleYears': 1,
  'scores': <dynamic>[],
  'reasons': <dynamic>[],
  'isFeasible': true,
};

Map<String, dynamic> _remote(String id, String crop, String createdAt) => {
  'id': id,
  'createdAt': createdAt,
  'lat': 52.4,
  'lon': 21.1,
  'goal': 'balanced',
  'plan': _plan(crop),
};

/// An account with some plans in it.
class _Account {
  _Account(this.plans);

  List<Map<String, dynamic>> plans;
  final posted = <String>[];
  final deleted = <String>[];
  int? failWith;
  var _next = 0;

  ApiClient get api => ApiClient(
    baseUrl: 'http://api',
    httpClient: MockClient((request) async {
      if (failWith != null) return http.Response('{}', failWith!);
      switch (request.method) {
        case 'GET':
          return http.Response(jsonEncode(plans), 200);
        case 'POST':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final crop = (body['plan']['cycle'] as List).first['crop']['id'];
          posted.add(crop as String);
          final id = 'new${_next++}';
          plans.add(_remote(id, crop, '2026-11-20T10:00:00Z'));
          return http.Response(jsonEncode({'id': id}), 201);
        default:
          deleted.add(request.url.pathSegments.last);
          plans.removeWhere((p) => p['id'] == request.url.pathSegments.last);
          return http.Response('', 204);
      }
    }),
  );
}

class _FakeAuth implements AuthRepository {
  @override
  Future<AccountSession> testLogin() async => const AccountSession(
    token: 'tok',
    user: AccountUser(id: '1', username: 'test'),
  );

  @override
  Future<AccountSession> login({
    required String username,
    required String password,
  }) => testLogin();

  @override
  Future<AccountSession> register({
    required String username,
    required String password,
  }) => testLogin();

  @override
  Future<AccountUser> me(String token) async =>
      const AccountUser(id: '1', username: 'test');

  @override
  Future<void> logout(String token) async {}
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

Future<void> _saveOnPhone(LocalPlansStore store, String crop) => store.add(
  parcelId: null,
  lat: 52.4,
  lon: 21.1,
  goal: 'balanced',
  plan: RotationPlan.fromJson(_plan(crop)),
  answers: const RotationAnswers(pastCrops: []),
);

List<String> _crops(LocalPlansStore store) => [
  for (final p in store.items) p.plan.cycle.single.crop.id,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('plans saved without an account survive a restart', () async {
    final first = LocalPlansStore(apiClient: _Account([]).api);
    await _saveOnPhone(first, 'Oats');

    final second = LocalPlansStore(apiClient: _Account([]).api);
    await second.load();

    expect(_crops(second), ['Oats']);
  });

  test('saving the same plan twice keeps one', () async {
    final store = LocalPlansStore(apiClient: _Account([]).api);
    await _saveOnPhone(store, 'Oats');
    await _saveOnPhone(store, 'Oats');

    expect(store.items, hasLength(1));
  });

  test(
    'signing in uploads plans from the phone and loads the account\'s',
    () async {
      final account = _Account([_remote('r1', 'Rye', '2026-11-01T10:00:00Z')]);
      final store = LocalPlansStore(apiClient: account.api);
      await _saveOnPhone(store, 'Oats');
      final auth = AuthStore(repository: _FakeAuth());
      store.attach(auth);

      await auth.login('a', 'b');
      await _settle();

      expect(account.posted, ['Oats']);
      expect(_crops(store)..sort(), ['Oats', 'Rye']);
      expect(store.items.every((p) => p.serverId != null), isTrue);
    },
  );

  test('a plan that is in both places is kept once', () async {
    final account = _Account([_remote('r1', 'Oats', '2026-11-01T10:00:00Z')]);
    final store = LocalPlansStore(apiClient: account.api);
    await _saveOnPhone(store, 'Oats');
    final auth = AuthStore(repository: _FakeAuth());
    store.attach(auth);

    await auth.login('a', 'b');
    await _settle();

    expect(account.posted, isEmpty);
    expect(store.items, hasLength(1));
    expect(store.items.single.serverId, 'r1');
  });

  test('a plan deleted from the account elsewhere leaves the phone', () async {
    final account = _Account([_remote('r1', 'Rye', '2026-11-01T10:00:00Z')]);
    final store = LocalPlansStore(apiClient: account.api);
    final auth = AuthStore(repository: _FakeAuth());
    store.attach(auth);
    await auth.login('a', 'b');
    await _settle();
    expect(_crops(store), ['Rye']);

    account.plans.clear(); // deleted on another device
    await store.sync();

    expect(store.items, isEmpty);
  });

  test('when the account is down the phone keeps everything', () async {
    final account = _Account([])..failWith = 503;
    final store = LocalPlansStore(apiClient: account.api);
    await _saveOnPhone(store, 'Oats');
    final auth = AuthStore(repository: _FakeAuth());
    store.attach(auth);

    await auth.login('a', 'b');
    await _settle();

    expect(_crops(store), ['Oats']);
    expect(store.items.single.serverId, isNull);

    // Back online: the next sync copies it.
    account.failWith = null;
    await store.sync();
    expect(account.posted, ['Oats']);
    expect(store.items.single.serverId, isNotNull);
  });

  test('a delete the account missed is retried', () async {
    final account = _Account([])..failWith = null;
    final store = LocalPlansStore(apiClient: account.api);
    final auth = AuthStore(repository: _FakeAuth());
    store.attach(auth);
    await auth.login('a', 'b');
    await _saveOnPhone(store, 'Oats');
    final item = store.items.single;
    expect(item.serverId, isNotNull);

    account.failWith = 503;
    await store.remove(item);
    expect(store.items, isEmpty);
    expect(account.plans, hasLength(1));

    account.failWith = null;
    await store.sync();
    expect(account.plans, isEmpty);
    expect(store.items, isEmpty);
  });

  test('signing out keeps the plans on the phone', () async {
    final account = _Account([]);
    final store = LocalPlansStore(apiClient: account.api);
    final auth = AuthStore(repository: _FakeAuth());
    store.attach(auth);
    await auth.login('a', 'b');
    await _saveOnPhone(store, 'Oats');

    await auth.signOut();

    expect(_crops(store), ['Oats']);
  });
}
