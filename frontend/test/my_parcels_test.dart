import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/components/my_plot_list.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/my_parcels_store.dart';
import 'package:hopito_field_shift/repositories/selected_plot_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Parcel _parcel(String id, {String? address}) => Parcel(
  id: id,
  center: const LatLng(52.4, 21.1),
  ring: const [
    LatLng(52.4, 21.1),
    LatLng(52.41, 21.1),
    LatLng(52.41, 21.11),
    LatLng(52.4, 21.1),
  ],
  address: address,
);

/// The account's side of the sync: last write wins per parcel.
class _Account {
  final stored = <String, Map<String, dynamic>>{};
  int? failWith;
  int calls = 0;

  ApiClient get api => ApiClient(
    baseUrl: 'http://api',
    httpClient: MockClient((request) async {
      calls++;
      if (failWith != null) return http.Response('{}', failWith!);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      for (final item in body['items'] as List) {
        final id = item['parcelId'] as String;
        final old = stored[id];
        if (old == null ||
            DateTime.parse(item['updatedAt'])
                .isAfter(DateTime.parse(old['updatedAt']))) {
          stored[id] = Map<String, dynamic>.from(item as Map);
        }
      }
      return http.Response(
        jsonEncode({
          'syncedAt': '2026-11-20T10:00:00Z',
          'items': stored.values.toList(),
        }),
        200,
      );
    }),
  );

  void put(Parcel parcel, String at, {bool deleted = false}) =>
      stored[parcel.id] = {
        'parcelId': parcel.id,
        'updatedAt': at,
        'deleted': deleted,
        if (!deleted) 'parcel': parcel.toJson(),
      };
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

List<String> _ids(MyParcelsStore s) => [for (final p in s.parcels) p.id];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MyParcelsStore', () {
    test('parcels added without an account survive a restart', () async {
      final account = _Account();
      final first = MyParcelsStore(apiClient: account.api);
      await first.add(_parcel('p1', address: 'Lipowa 1'));

      final second = MyParcelsStore(apiClient: account.api);
      await second.load();

      expect(_ids(second), ['p1']);
      expect(second.parcels.single.address, 'Lipowa 1');
      expect(account.calls, 0);
    });

    test('a removed parcel is gone, also after a restart', () async {
      final store = MyParcelsStore(apiClient: _Account().api);
      await store.add(_parcel('p1'));
      await store.add(_parcel('p2'));

      await store.remove('p1');
      final again = MyParcelsStore(apiClient: _Account().api);
      await again.load();

      expect(_ids(store), ['p2']);
      expect(_ids(again), ['p2']);
    });

    test(
      'signing in sends the phone\'s list and loads the account\'s',
      () async {
        final account = _Account()..put(_parcel('p2'), '2026-11-01T10:00:00Z');
        final store = MyParcelsStore(apiClient: account.api);
        await store.add(_parcel('p1'));
        final auth = AuthStore(repository: _FakeAuth());
        store.attach(auth);

        await auth.login('a', 'b');
        await _settle();

        expect(_ids(store)..sort(), ['p1', 'p2']);
        expect(account.stored.keys, containsAll(['p1', 'p2']));
        expect(store.syncedAt, isNotNull);
      },
    );

    test('another phone gets the list, and removals follow', () async {
      final account = _Account();
      final auth = AuthStore(repository: _FakeAuth());
      await auth.login('a', 'b');
      final phone1 = MyParcelsStore(apiClient: account.api)..attach(auth);
      await phone1.add(_parcel('p1'));
      await _settle();

      SharedPreferences.setMockInitialValues({}); // a different phone
      final phone2 = MyParcelsStore(apiClient: account.api)..attach(auth);
      await _settle();
      expect(_ids(phone2), ['p1']);

      await phone1.remove('p1');
      await _settle();
      await phone2.sync();

      expect(_ids(phone2), isEmpty);
    });

    test(
      'the newer change wins: removed elsewhere after being added here',
      () async {
        var now = DateTime.utc(2026, 11, 1);
        final account = _Account();
        final store = MyParcelsStore(apiClient: account.api, clock: () => now);
        await store.add(_parcel('p1'));
        account.put(_parcel('p1'), '2026-11-10T10:00:00Z', deleted: true);
        final auth = AuthStore(repository: _FakeAuth());
        now = DateTime.utc(2026, 11, 15);
        store.attach(auth);

        await auth.login('a', 'b');
        await _settle();

        expect(_ids(store), isEmpty);
      },
    );

    test(
      'the newer change wins: added here after being removed elsewhere',
      () async {
        var now = DateTime.utc(2026, 11, 20);
        final account = _Account();
        account.put(_parcel('p1'), '2026-11-10T10:00:00Z', deleted: true);
        final store = MyParcelsStore(apiClient: account.api, clock: () => now);
        await store.add(_parcel('p1'));
        final auth = AuthStore(repository: _FakeAuth());
        store.attach(auth);

        await auth.login('a', 'b');
        await _settle();

        expect(_ids(store), ['p1']);
        expect(account.stored['p1']!['deleted'], isFalse);
      },
    );

    test('when the account is down the phone keeps the list', () async {
      final account = _Account()..failWith = 503;
      final store = MyParcelsStore(apiClient: account.api);
      await store.add(_parcel('p1'));
      final auth = AuthStore(repository: _FakeAuth());
      store.attach(auth);

      await auth.login('a', 'b');
      await _settle();

      expect(_ids(store), ['p1']);
      expect(store.syncedAt, isNull);

      account.failWith = null;
      await store.sync();
      expect(account.stored.keys, ['p1']);
      expect(store.syncedAt, isNotNull);
    });

    test('an expired sign-in signs out but keeps the list', () async {
      final account = _Account()..failWith = 401;
      final store = MyParcelsStore(apiClient: account.api);
      await store.add(_parcel('p1'));
      final auth = AuthStore(repository: _FakeAuth());
      store.attach(auth);

      await auth.login('a', 'b');
      await _settle();

      expect(auth.status, AuthStatus.guest);
      expect(_ids(store), ['p1']);
    });

    test('a parcel chosen before the list existed is taken into it', () async {
      final selected = SelectedPlotStore();
      await selected.select(_parcel('old'));
      final store = MyParcelsStore(apiClient: _Account().api);

      await store.bind(selected);

      expect(_ids(store), ['old']);
      expect(selected.parcel?.id, 'old');
    });

    test('removing the active parcel clears it', () async {
      final selected = SelectedPlotStore();
      final store = MyParcelsStore(apiClient: _Account().api);
      await store.bind(selected);
      await store.add(_parcel('p1'));
      await selected.select(_parcel('p1'));

      await store.remove('p1');

      expect(selected.parcel, isNull);
    });
  });

  Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: Scaffold(body: home),
  );

  group('adding a parcel', () {
    late MyParcelsStore mine;
    late SelectedPlotStore selected;
    bool? result;

    Future<void> open(WidgetTester tester) async {
      mine = MyParcelsStore(apiClient: _Account().api);
      selected = SelectedPlotStore();
      result = null;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await offerMyParcel(
                context,
                parcel: _parcel('p1', address: 'Lipowa 1'),
                store: selected,
                parcels: mine,
              ),
              child: const Text('pick'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks if it is the user\'s parcel; Yes adds it', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Is this your parcel?'), findsOneWidget);
      expect(find.text('Is Lipowa 1 your parcel?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(_ids(mine), ['p1']);
      expect(selected.parcel?.id, 'p1');
      expect(result, isTrue);
      expect(find.text('Parcel added to your parcels.'), findsOneWidget);
    });

    testWidgets('No changes nothing', (tester) async {
      await open(tester);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(mine.parcels, isEmpty);
      expect(selected.parcel, isNull);
      expect(result, isFalse);
    });

    testWidgets('a parcel already on the list is not asked about again', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      expect(find.text('Is this your parcel?'), findsNothing);
      expect(result, isTrue);
    });
  });

  group('removing a parcel', () {
    late List<String> removed;

    Future<void> open(WidgetTester tester) async {
      removed = [];
      await tester.pumpWidget(
        app(
          MyPlotList(
            parcels: [
              _parcel('p1', address: 'Lipowa 1'),
              _parcel('p2'),
            ],
            selectedId: 'p2',
            onSelected: (_) {},
            onRemoved: (p) => removed.add(p.id),
          ),
        ),
      );
    }

    testWidgets('swiping right asks first, then removes', (tester) async {
      await open(tester);

      await tester.drag(find.text('Lipowa 1'), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Remove this parcel?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(removed, ['p1']);
    });

    testWidgets('cancelling keeps the parcel', (tester) async {
      await open(tester);

      await tester.drag(find.text('Lipowa 1'), const Offset(600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(removed, isEmpty);
      expect(find.text('Lipowa 1'), findsOneWidget);
    });

    testWidgets('swiping left does nothing', (tester) async {
      await open(tester);

      await tester.drag(find.text('Lipowa 1'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Remove this parcel?'), findsNothing);
    });
  });
}
