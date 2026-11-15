import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hopito_field_shift/app/app_theme.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/components/account_button.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/pages/my_plans_page.dart';
import 'package:hopito_field_shift/pages/saved_plan_page.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/local_plans_store.dart';
import 'package:hopito_field_shift/repositories/saved_plans_repository.dart';
import 'package:hopito_field_shift/repositories/selected_plot_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
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
  'scores': [
    {
      'key': 'humus',
      'rating': {'value': 0.4, 'level': 'ok'},
    },
  ],
  'reasons': <dynamic>[],
  'isFeasible': true,
};

Map<String, dynamic> _saved(String id, String crop, String createdAt) => {
  'id': id,
  'createdAt': createdAt,
  'parcelId': 'p1',
  'lat': 52.4,
  'lon': 21.1,
  'goal': 'balanced',
  'plan': _plan(crop),
};

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
  }) => throw UnimplementedError();

  @override
  Future<AccountSession> register({
    required String username,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> me(String token) async =>
      const AccountUser(id: '1', username: 'test');

  @override
  Future<void> logout(String token) async {}
}

Future<AuthStore> _signedIn() async {
  final store = AuthStore(repository: _FakeAuth());
  await store.testLogin();
  return store;
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    FLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  theme: AppTheme.material(AppTheme.light),
  builder: (context, child) => FTheme(data: AppTheme.light, child: child!),
  home: home,
);

/// A store holding [crops] as plans saved on the phone (newest first), with
/// a backend that records what is deleted from the account.
Future<LocalPlansStore> _store(
  List<String> crops, {
  List<String>? deleted,
  AuthStore? auth,
}) async {
  SharedPreferences.setMockInitialValues({
    'local_plans': jsonEncode([
      for (var i = 0; i < crops.length; i++)
        {
          'id': 'l$i',
          if (auth != null) 'serverId': 's$i',
          'createdAt': '2026-11-${15 - i}T10:00:00Z',
          'goal': 'balanced',
          'lat': 52.4,
          'lon': 21.1,
          'plan': _plan(crops[i]),
        },
    ]),
  });
  final store = LocalPlansStore(
    apiClient: ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((request) async {
        if (request.method == 'DELETE') {
          deleted?.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode([
            if (auth != null)
              for (var i = 0; i < crops.length; i++)
                _saved('s$i', crops[i], '2026-11-${15 - i}T10:00:00Z'),
          ]),
          200,
        );
      }),
    ),
  );
  await store.load();
  return store;
}

Future<void> _openPage(WidgetTester tester, LocalPlansStore store) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(MyPlansPage(plans: store)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SavedPlansRepository', () {
    test('lists the plans with the token and parses them', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode([_saved('a', 'Oats', '2026-11-15T10:00:00Z')]),
          200,
        );
      });
      final repo = SavedPlansRepository(
        apiClient: ApiClient(httpClient: client, baseUrl: 'http://api'),
      );

      final plans = await repo.list('secret');

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/me/plans');
      expect(seen.headers['Authorization'], 'Bearer secret');
      expect(plans.single.id, 'a');
      expect(plans.single.goal, 'balanced');
      expect(plans.single.plan.cycle.single.crop.id, 'Oats');
      expect(plans.single.createdAt.isUtc, isTrue);
    });

    test('deletes one plan by id', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('', 204);
      });
      final repo = SavedPlansRepository(
        apiClient: ApiClient(httpClient: client, baseUrl: 'http://api'),
      );

      await repo.delete('secret', 'abc');

      expect(seen.method, 'DELETE');
      expect(seen.url.toString(), 'http://api/api/me/plans/abc');
      expect(seen.headers['Authorization'], 'Bearer secret');
    });

    test('a 404 on delete is an ApiException with the status', () async {
      final client = MockClient((_) async => http.Response('', 404));
      final repo = SavedPlansRepository(
        apiClient: ApiClient(httpClient: client, baseUrl: 'http://api'),
      );

      await expectLater(
        repo.delete('t', 'abc'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('My plans page', () {
    testWidgets('lists the plans on the phone, without any account', (
      tester,
    ) async {
      await _openPage(tester, await _store(['Oats', 'Rye']));

      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Rye'), findsOneWidget);
      expect(find.textContaining('saved Nov 15, 2026'), findsOneWidget);
      expect(find.textContaining('saved Nov 14, 2026'), findsOneWidget);
    });

    testWidgets('says so when nothing is saved yet', (tester) async {
      await _openPage(tester, await _store([]));

      expect(
        find.text(
          'You have no saved plans yet. Open a report and choose Save this plan.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('deleting asks first and then removes the plan', (
      tester,
    ) async {
      await _openPage(tester, await _store(['Oats', 'Rye']));

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete this plan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Oats'), findsNothing);
      expect(find.text('Rye'), findsOneWidget);
      expect(find.text('Plan deleted.'), findsOneWidget);
    });

    testWidgets('cancelling the question keeps the plan', (tester) async {
      await _openPage(tester, await _store(['Oats']));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Oats'), findsOneWidget);
    });

    testWidgets('a plan copied to the account is deleted there too', (
      tester,
    ) async {
      final deleted = <String>[];
      final auth = await _signedIn();
      final store = await _store(['Oats'], deleted: deleted, auth: auth)
        ..attach(auth);
      await _openPage(tester, store);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleted, contains('s0'));
      expect(find.text('Oats'), findsNothing);
    });

    testWidgets('tapping a plan opens it with its rating bars', (tester) async {
      await _openPage(tester, await _store(['Oats', 'Rye']));

      await tester.tap(find.text('Oats'));
      await tester.pumpAndSettle();

      expect(find.byType(SavedPlanPage), findsOneWidget);
      expect(find.text('All ratings'), findsOneWidget);
      expect(find.textContaining('Saved Nov 15, 2026'), findsOneWidget);
    });
  });

  group('Account sheet', () {
    Future<void> openSheet(WidgetTester tester, AuthStore store) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            appBar: AppBar(
              actions: [
                AccountButton(store: store, plotStore: SelectedPlotStore()),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
    }

    testWidgets('a signed-in user can open My plans', (tester) async {
      await openSheet(tester, await _signedIn());

      await tester.tap(find.widgetWithText(FilledButton, 'My plans'));
      await tester.pumpAndSettle();

      expect(find.byType(MyPlansPage), findsOneWidget);
    });

    testWidgets('a guest can open My plans too', (tester) async {
      await openSheet(tester, AuthStore(repository: _FakeAuth()));

      await tester.tap(find.widgetWithText(FilledButton, 'My plans'));
      await tester.pumpAndSettle();

      expect(find.byType(MyPlansPage), findsOneWidget);
    });
  });
}
