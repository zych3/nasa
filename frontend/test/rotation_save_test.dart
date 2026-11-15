import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/models/climate_trends.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/models/rotation_report.dart';
import 'package:hopito_field_shift/pages/auth_page.dart';
import 'package:hopito_field_shift/pages/rotation_report_page.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/climate_trends_repository.dart';
import 'package:hopito_field_shift/repositories/rotation_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _plan(String crop, double harvest) => {
  'transition': <dynamic>[],
  'cycle': [
    {
      'harvestYear': 2027,
      'crop': {
        'id': crop,
        'name': {'en': crop, 'pl': crop},
      },
      'harvest': {'value': harvest, 'level': 'good'},
    },
  ],
  'cycleYears': 1,
  'scores': [
    {
      'key': 'harvest',
      'rating': {'value': harvest, 'level': 'good'},
    },
    {
      'key': 'humus',
      'rating': {'value': 0.4, 'level': 'ok'},
    },
  ],
  'reasons': <dynamic>[],
  'isFeasible': true,
};

Map<String, dynamic> _reportJson() => {
  'status': 'ok',
  'mainGoal': 'balanced',
  'recommendations': [
    {
      'goal': 'balanced',
      'best': _plan('Oats', 0.8),
      'alternatives': [_plan('Rye', 0.5)],
    },
  ],
  'warnings': <dynamic>[],
  'inputs': <dynamic>[],
};

class _Saved {
  _Saved(this.token, this.goal, this.plan);
  final String token;
  final String goal;
  final RotationPlan plan;
}

class _FakeRotations extends RotationRepository {
  final saved = <_Saved>[];
  Object? failWith;

  @override
  Future<RotationReport> getReport({
    required String? parcelId,
    required double lat,
    required double lon,
    required RotationAnswers answers,
  }) async => RotationReport.fromJson(_reportJson());

  @override
  Future<void> savePlan({
    required String authToken,
    required String? parcelId,
    required double lat,
    required double lon,
    required String goal,
    required RotationPlan plan,
    required RotationAnswers answers,
  }) async {
    if (failWith != null) throw failWith!;
    saved.add(_Saved(authToken, goal, plan));
  }
}

/// The climate section under the plan has its own tests; here it stays empty
/// (and makes no HTTP request, which would never finish in a widget test).
class _NoClimate extends ClimateTrendsRepository {
  @override
  Future<ClimateTrends?> getTrends({
    required String? parcelId,
    required double lat,
    required double lon,
  }) async => null;
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

final _parcel = Parcel(
  id: 'p1',
  center: const LatLng(52.4, 21.1),
  ring: const [],
);

Future<void> _open(
  WidgetTester tester,
  _FakeRotations repo,
  AuthStore store,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: RotationReportPage(
        parcel: _parcel,
        answers: const RotationAnswers(pastCrops: ['rye']),
        authStore: store,
        repository: repo,
        climateRepository: _NoClimate(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<AuthStore> _signedIn() async {
  final store = AuthStore(repository: _FakeAuth());
  await store.testLogin();
  return store;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RotationRepository.savePlan', () {
    test(
      'posts the plan as received, with the token and the answers',
      () async {
        late http.Request seen;
        final client = MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'id': 'x'}), 201);
        });
        final repo = RotationRepository(
          apiClient: ApiClient(httpClient: client, baseUrl: 'http://api'),
        );
        final plan = RotationPlan.fromJson(_plan('Oats', 0.8));

        await repo.savePlan(
          authToken: 'secret',
          parcelId: 'p1',
          lat: 52.4,
          lon: 21.1,
          goal: 'balanced',
          plan: plan,
          answers: const RotationAnswers(pastCrops: ['rye']),
        );

        expect(seen.method, 'POST');
        expect(seen.url.toString(), 'http://api/api/me/plans');
        expect(seen.headers['Authorization'], 'Bearer secret');
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['goal'], 'balanced');
        expect(body['parcelId'], 'p1');
        expect(body['plan'], plan.raw);
        expect((body['answers'] as Map)['pastCrops'], ['rye']);
      },
    );

    test('the backend error code reaches the caller', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'code': 'too_many_plans'}), 400),
      );
      final repo = RotationRepository(
        apiClient: ApiClient(httpClient: client, baseUrl: 'http://api'),
      );

      await expectLater(
        repo.savePlan(
          authToken: 't',
          parcelId: null,
          lat: 1,
          lon: 1,
          goal: 'balanced',
          plan: RotationPlan.fromJson(_plan('Oats', 0.8)),
          answers: const RotationAnswers(pastCrops: []),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'too_many_plans'),
        ),
      );
    });
  });

  group('report page', () {
    testWidgets('saves the shown plan and then says it is saved', (
      tester,
    ) async {
      final repo = _FakeRotations();
      await _open(tester, repo, await _signedIn());

      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.token, 'tok');
      expect(repo.saved.single.goal, 'balanced');
      expect(repo.saved.single.plan.cycle.single.crop.id, 'Oats');
      expect(find.text('Plan saved'), findsOneWidget);
      expect(find.text('The plan is saved in your profile.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Plan saved'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a plan chosen in More details becomes the one that is saved', (
      tester,
    ) async {
      final repo = _FakeRotations();
      await _open(tester, repo, await _signedIn());

      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      // The option shows its own rating bars before it is chosen.
      expect(find.text('All ratings'), findsWidgets);
      await tester.tap(find.text('Choose this plan'));
      await tester.pumpAndSettle();

      expect(
        find.text('You are looking at option 1, not the recommended plan.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(repo.saved.single.plan.cycle.single.crop.id, 'Rye');
    });

    testWidgets('going back to the recommended plan saves that one', (
      tester,
    ) async {
      final repo = _FakeRotations();
      await _open(tester, repo, await _signedIn());
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose this plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show recommended'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(repo.saved.single.plan.cycle.single.crop.id, 'Oats');
    });

    testWidgets('without an account the sign-in page opens first', (
      tester,
    ) async {
      final repo = _FakeRotations();
      await _open(tester, repo, AuthStore(repository: _FakeAuth()));

      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(repo.saved, isEmpty);
    });

    testWidgets('an expired sign-in is reported and the user is signed out', (
      tester,
    ) async {
      final repo = _FakeRotations()
        ..failWith = ApiException('x', statusCode: 401);
      final store = await _signedIn();
      await _open(tester, repo, store);

      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(
        find.text('Your sign-in expired. Please sign in again.'),
        findsOne,
      );
      expect(store.status, AuthStatus.guest);
      expect(find.text('Save this plan'), findsOneWidget);
    });

    testWidgets('too many saved plans gets its own message', (tester) async {
      final repo = _FakeRotations()
        ..failWith = ApiException('x', statusCode: 400, code: 'too_many_plans');
      await _open(tester, repo, await _signedIn());

      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(
        find.text('You have too many saved plans. Delete one first.'),
        findsOneWidget,
      );
      expect(find.text('Save this plan'), findsOneWidget);
    });

    testWidgets('any other failure says the save failed', (tester) async {
      final repo = _FakeRotations()..failWith = Exception('network');
      await _open(tester, repo, await _signedIn());

      await tester.tap(find.text('Save this plan'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save the plan. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
