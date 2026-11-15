import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/components/account_button.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/models/saved_plan.dart';
import 'package:hopito_field_shift/pages/my_plans_page.dart';
import 'package:hopito_field_shift/pages/saved_plan_page.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
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

class _FakeRepo extends SavedPlansRepository {
  _FakeRepo(this.items);

  List<SavedPlan> items;
  Object? listError;
  Object? deleteError;
  final deleted = <String>[];
  int listCalls = 0;

  @override
  Future<List<SavedPlan>> list(String authToken) async {
    listCalls++;
    if (listError != null) throw listError!;
    return items;
  }

  @override
  Future<void> delete(String authToken, String id) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(id);
  }
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

List<SavedPlan> _two() => [
  SavedPlan.fromJson(_saved('a', 'Oats', '2026-11-15T10:00:00Z')),
  SavedPlan.fromJson(_saved('b', 'Rye', '2026-11-14T10:00:00Z')),
];

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: home,
);

Future<void> _openPage(
  WidgetTester tester,
  _FakeRepo repo,
  AuthStore store,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(MyPlansPage(authStore: store, repository: repo)),
  );
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
    testWidgets('lists the saved plans with their crops and date', (
      tester,
    ) async {
      await _openPage(tester, _FakeRepo(_two()), await _signedIn());

      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Rye'), findsOneWidget);
      expect(find.textContaining('saved Nov 15, 2026'), findsOneWidget);
      expect(find.textContaining('saved Nov 14, 2026'), findsOneWidget);
    });

    testWidgets('says so when nothing is saved yet', (tester) async {
      await _openPage(tester, _FakeRepo([]), await _signedIn());

      expect(
        find.text(
          'You have no saved plans yet. Open a report and choose Save this plan.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed load can be retried', (tester) async {
      final repo = _FakeRepo(_two())..listError = Exception('down');
      await _openPage(tester, repo, await _signedIn());
      expect(find.text('Could not load your plans.'), findsOneWidget);

      repo.listError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repo.listCalls, 2);
      expect(find.text('Oats'), findsOneWidget);
    });

    testWidgets('an expired sign-in signs the user out', (tester) async {
      final repo = _FakeRepo([])
        ..listError = ApiException('x', statusCode: 401);
      final store = await _signedIn();
      await _openPage(tester, repo, store);

      expect(
        find.text('Your sign-in expired. Please sign in again.'),
        findsOne,
      );
      expect(store.status, AuthStatus.guest);
    });

    testWidgets('deleting asks first and then removes the plan', (
      tester,
    ) async {
      final repo = _FakeRepo(_two());
      await _openPage(tester, repo, await _signedIn());

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete this plan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleted, ['a']);
      expect(find.text('Oats'), findsNothing);
      expect(find.text('Rye'), findsOneWidget);
      expect(find.text('Plan deleted.'), findsOneWidget);
    });

    testWidgets('cancelling the question keeps the plan', (tester) async {
      final repo = _FakeRepo(_two());
      await _openPage(tester, repo, await _signedIn());

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleted, isEmpty);
      expect(find.text('Oats'), findsOneWidget);
    });

    testWidgets('a failed delete keeps the plan and says so', (tester) async {
      final repo = _FakeRepo(_two())..deleteError = Exception('down');
      await _openPage(tester, repo, await _signedIn());

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Oats'), findsOneWidget);
      expect(
        find.text('Could not delete the plan. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a plan that is already gone counts as deleted', (
      tester,
    ) async {
      final repo = _FakeRepo(_two())
        ..deleteError = ApiException('x', statusCode: 404);
      await _openPage(tester, repo, await _signedIn());

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Oats'), findsNothing);
      expect(find.text('Plan deleted.'), findsOneWidget);
    });

    testWidgets('tapping a plan opens it with its rating bars', (tester) async {
      await _openPage(tester, _FakeRepo(_two()), await _signedIn());

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

    testWidgets('a guest has no My plans button', (tester) async {
      await openSheet(tester, AuthStore(repository: _FakeAuth()));

      expect(find.text('My plans'), findsNothing);
    });
  });
}
