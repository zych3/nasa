import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/testing.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/components/rotation/climate_trends_section.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/l10n/climate_trend_text.dart';
import 'package:hopito_field_shift/models/account.dart';
import 'package:hopito_field_shift/models/climate_trends.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/models/rotation_report.dart';
import 'package:hopito_field_shift/pages/rotation_report_page.dart';
import 'package:hopito_field_shift/repositories/auth_repository.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/climate_trends_repository.dart';
import 'package:hopito_field_shift/repositories/rotation_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The saved real response the app ships (parcel 141205_2.0008.60).
Map<String, dynamic> _savedJson() => jsonDecode(
  File('assets/mock/parcel_climate_trends.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> _trend({
  String id = 'hot_days',
  String change = 'more_heat',
  String direction = 'up',
  String unit = 'days',
  double early = 7,
  double recent = 13,
  List<String> advice = const ['heat_tolerant_varieties'],
}) => {
  'id': id,
  'change': change,
  'direction': direction,
  'unit': unit,
  'earlyMean': early,
  'recentMean': recent,
  'earlyFrom': 1981,
  'earlyTo': 1995,
  'recentFrom': 2011,
  'recentTo': 2025,
  'pValue': 0.002,
  'alsoSeenIn': <String>[],
  'adviceCodes': advice,
  'years': <int>[],
  'values': <double>[],
};

ClimateTrends _trends({
  String status = 'ok',
  List<Map<String, dynamic>> trends = const [],
  List<String> notes = const ['regional_climate_grid'],
}) => ClimateTrends.fromJson({
  'parcelId': 'p1',
  'status': status,
  'fromYear': 1981,
  'toYear': 2025,
  'gridKm': 50,
  'source': 'NASA POWER (MERRA-2)',
  'sourceKind': 'estimated',
  'noteCodes': notes,
  'trends': trends,
});

class _FakeClimate extends ClimateTrendsRepository {
  _FakeClimate(this.answer);
  final Future<ClimateTrends?> answer;

  @override
  Future<ClimateTrends?> getTrends({
    required String? parcelId,
    required double lat,
    required double lon,
  }) => answer;
}

class _FakeRotations extends RotationRepository {
  @override
  Future<RotationReport> getReport({
    required String? parcelId,
    required double lat,
    required double lon,
    required RotationAnswers answers,
  }) async => RotationReport.fromJson({
    'status': 'ok',
    'mainGoal': 'balanced',
    'recommendations': [
      {
        'goal': 'balanced',
        'best': {
          'transition': <dynamic>[],
          'cycle': [
            {
              'harvestYear': 2027,
              'crop': {
                'id': 'oats',
                'name': {'en': 'Oats', 'pl': 'Owies'},
              },
              'harvest': {'value': 0.8, 'level': 'good'},
            },
          ],
          'cycleYears': 1,
          'scores': [
            {
              'key': 'harvest',
              'rating': {'value': 0.8, 'level': 'good'},
            },
          ],
          'reasons': <dynamic>[],
          'isFeasible': true,
        },
        'alternatives': <dynamic>[],
      },
    ],
    'warnings': <dynamic>[],
    'inputs': <dynamic>[],
  });
}

class _NoAuth implements AuthRepository {
  @override
  Future<AccountSession> testLogin() => throw UnimplementedError();

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
  Future<AccountUser> me(String token) => throw UnimplementedError();

  @override
  Future<void> logout(String token) async {}
}

Future<void> _open(
  WidgetTester tester,
  Future<ClimateTrends?> climate, {
  Size size = const Size(800, 4000),
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RotationReportPage(
        parcel: const Parcel(id: 'p1', center: LatLng(52.4, 21.1), ring: []),
        answers: const RotationAnswers(pastCrops: ['rye']),
        authStore: AuthStore(repository: _NoAuth()),
        repository: _FakeRotations(),
        climateRepository: _FakeClimate(climate),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final pl = lookupAppLocalizations(const Locale('pl'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('texts', () {
    // Month names; in the app the Material localizations load them.
    setUpAll(() => initializeDateFormatting());

    test('a trend is two means of past years, with units', () {
      final hot = ClimateTrend.fromJson(_trend());

      expect(
        climateFactText(en, 'en', hot),
        'On average 7 days in 1981–1995, and 13 days in 2011–2025.',
      );
      expect(
        climateFactText(pl, 'pl', hot),
        'Średnio 7 dni w latach 1981–1995, a 13 dni w latach 2011–2025.',
      );
      expect(
        climateTrendHeadline(pl, hot),
        'Więcej upalnych dni (30 °C i więcej)',
      );
    });

    test('a day of the year is shown as a date, other units with a name', () {
      final frost = ClimateTrend.fromJson(
        _trend(
          id: 'last_spring_frost',
          direction: 'down',
          unit: 'day_of_year',
          early: 120,
          recent: 110,
        ),
      );
      expect(climateValueText(en, 'en', frost, 120), 'April 30');
      expect(climateValueText(pl, 'pl', frost, 110), '20 kwietnia');
      expect(climateTrendHeadline(en, frost), en.climateLastSpringFrostDown);

      ClimateTrend unit(String u) => ClimateTrend.fromJson(_trend(unit: u));
      expect(climateValueText(en, 'en', unit('celsius'), 34.5), '34.5 °C');
      expect(climateValueText(pl, 'pl', unit('celsius'), 34.5), '34,5 °C');
      expect(climateValueText(en, 'en', unit('millimetres'), -293), '-293 mm');
      expect(
        climateValueText(en, 'en', unit('degree_days'), 1291),
        '1,291 heat units',
      );
      expect(climateValueText(pl, 'pl', unit('days'), 1), '1 dzień');
      expect(climateValueText(pl, 'pl', unit('days'), 3), '3 dni');
    });

    test('every code of the backend has words in both languages', () {
      const ids = {
        'frost_free_days': 'days',
        'last_spring_frost': 'day_of_year',
        'first_autumn_frost': 'day_of_year',
        'hot_days': 'days',
        'max_temperature': 'celsius',
        'growing_degree_days': 'degree_days',
        'longest_dry_spell': 'days',
        'season_precipitation': 'millimetres',
        'water_balance': 'millimetres',
        'heavy_rain_days': 'days',
      };
      const advice = [
        'heat_tolerant_varieties',
        'keep_soil_covered',
        'drought_crops_on_light_soil',
        'use_longer_season',
        'do_not_sow_earlier',
        'check_warm_season_crops',
        'protect_from_erosion',
        'work_across_slope',
      ];
      const notes = [
        'regional_climate_grid',
        'frost_measured_in_air',
        'evaporation_estimated_from_temperature',
      ];
      for (final l10n in [en, pl]) {
        for (final e in ids.entries) {
          for (final direction in ['up', 'down']) {
            final t = ClimateTrend.fromJson(
              _trend(id: e.key, unit: e.value, direction: direction),
            );
            expect(climateTrendHeadline(l10n, t), isNotNull, reason: e.key);
            expect(climateFactText(l10n, l10n.localeName, t), isNotNull);
          }
        }
        for (final code in advice) {
          expect(climateAdviceText(l10n, code), isNotNull, reason: code);
        }
        for (final code in notes) {
          expect(climateNoteText(l10n, code, 50), isNotNull, reason: code);
        }
      }
    });

    test('unknown codes give nothing, never the raw code', () {
      expect(climateAdviceText(en, 'buy_more_land'), isNull);
      expect(climateNoteText(en, 'new_note', 50), isNull);
      final unknown = _trends(
        trends: [
          _trend(id: 'wind_speed'),
          _trend(unit: 'furlongs'),
        ],
      );
      expect(climateTrendsToShow(en, 'en', unknown), isEmpty);
      // Nothing to say and no "no clear trends" verdict: the section is silent.
      expect(climateSectionTexts(en, 'en', unknown), isEmpty);
    });

    test('nothing is said about the future', () {
      for (final l10n in [en, pl]) {
        final all = climateSectionTexts(
          l10n,
          l10n.localeName,
          ClimateTrends.fromJson(_savedJson()),
        ).join(' ').toLowerCase();
        for (final word in ['will ', 'forecasts', 'będzie', 'za 10 lat']) {
          expect(all.contains(word), isFalse, reason: word);
        }
        expect(all, contains(l10n.climateNotForecast.toLowerCase()));
      }
    });
  });

  group('ClimateTrendsRepository', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    ClimateTrendsRepository repo(http.Client client, {bool useMock = false}) =>
        ClimateTrendsRepository(
          apiClient: ApiClient(httpClient: client, baseUrl: 'http://api'),
          useMock: useMock,
        );

    test('asks the backend for the parcel', () async {
      late Uri seen;
      final client = MockClient((request) async {
        seen = request.url;
        return http.Response.bytes(
          utf8.encode(jsonEncode(_savedJson())),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final trends = await repo(client)
          .getTrends(parcelId: 'p9', lat: 52.2, lon: 21.48);

      expect(seen.path, '/api/parcels/climate-trends');
      expect(seen.queryParameters, {
        'parcelId': 'p9',
        'lat': '52.2',
        'lon': '21.48',
      });
      expect(trends!.status, 'ok');
      expect(trends.trends, isNotEmpty);
    });

    test('backend down: the saved copy, but only for its own parcel', () async {
      final down = MockClient((_) async => http.Response('', 502));
      final savedParcel = _savedJson()['parcelId'] as String;

      final same = await repo(down)
          .getTrends(parcelId: savedParcel, lat: 52.2, lon: 21.48);
      final other = await repo(down)
          .getTrends(parcelId: 'somewhere_else', lat: 50, lon: 20);
      final point = await repo(down)
          .getTrends(parcelId: null, lat: 50, lon: 20);

      expect(same!.parcelId, savedParcel);
      expect(other, isNull);
      expect(point, isNull);
    });

    test('demo mode never calls the backend', () async {
      final client = MockClient((_) async => fail('called the backend'));

      final trends = await repo(
        client,
        useMock: true,
      ).getTrends(parcelId: 'p1', lat: 1, lon: 2);

      expect(trends!.hasTrends, isTrue);
    });
  });

  group('report page', () {
    testWidgets('shows the saved trends under the plan', (tester) async {
      final saved = ClimateTrends.fromJson(_savedJson());
      await _open(tester, Future.value(saved));

      expect(find.text('Oats'), findsWidgets);
      expect(find.text(en.climateSectionTitle), findsOneWidget);
      expect(find.text(en.climateHotDaysUp), findsOneWidget);
      expect(
        find.text('On average 7 days in 1981–1995, and 13 days in 2011–2025.'),
        findsOneWidget,
      );
      expect(find.text(en.climateAdviceHeatTolerantVarieties), findsOneWidget);
      expect(find.text(en.climateNotForecast), findsOneWidget);
      expect(find.text(en.climateNoteRegional('50')), findsOneWidget);
      expect(
        find.text(en.climateSource('NASA POWER (MERRA-2)', '1981', '2025')),
        findsOneWidget,
      );
      // Direction is an icon and a word, not colour alone.
      expect(
        find.byIcon(Icons.trending_up),
        findsNWidgets(saved.trends.length),
      );
      // The section is the last thing in the report, below the plan's buttons.
      expect(
        tester.getTopLeft(find.byType(ClimateTrendsSection)).dy,
        greaterThan(tester.getTopLeft(find.text(en.reportDone)).dy),
      );
    });

    testWidgets('trends that cannot be loaded leave the plan untouched', (
      tester,
    ) async {
      await _open(tester, Future.value(null));

      expect(find.text('Oats'), findsWidgets);
      expect(find.text(en.reportSavePlan), findsOneWidget);
      expect(find.text(en.climateSectionTitle), findsNothing);
      expect(find.text(en.climateLoading), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the plan does not wait for the trends', (tester) async {
      final never = Completer<ClimateTrends?>();
      await _open(tester, never.future, settle: false);

      expect(find.text('Oats'), findsWidgets);
      expect(find.text(en.climateLoading), findsOneWidget);
      expect(find.text(en.climateSectionTitle), findsNothing);
    });

    testWidgets('no clear trends is said plainly', (tester) async {
      await _open(tester, Future.value(_trends(status: 'no_clear_trends')));

      expect(find.text(en.climateSectionTitle), findsOneWidget);
      expect(
        find.text(en.climateNoClearTrends('1981', '2025')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.trending_up), findsNothing);
      expect(find.text(en.climateNoteRegional('50')), findsOneWidget);
    });

    testWidgets('too little data shows nothing', (tester) async {
      await _open(
        tester,
        Future.value(_trends(status: 'no_data', notes: const [])),
      );

      expect(find.text(en.climateSectionTitle), findsNothing);
    });

    testWidgets('advice for the parcel and notes come from the codes', (
      tester,
    ) async {
      await _open(
        tester,
        Future.value(
          _trends(
            notes: const [
              'regional_climate_grid',
              'evaporation_estimated_from_temperature',
              'brand_new_note',
            ],
            trends: [
              _trend(
                id: 'water_balance',
                change: 'drier',
                direction: 'down',
                unit: 'millimetres',
                early: -183,
                recent: -236,
                advice: const [
                  'keep_soil_covered',
                  'drought_crops_on_light_soil',
                  'brand_new_advice',
                ],
              ),
            ],
          ),
        ),
      );

      expect(find.text(en.climateWaterBalanceDown), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
      expect(find.text(en.climateAdviceKeepSoilCovered), findsOneWidget);
      expect(
        find.text(en.climateAdviceDroughtCropsOnLightSoil),
        findsOneWidget,
      );
      expect(find.text(en.climateNoteEvaporation), findsOneWidget);
      expect(find.textContaining('brand_new'), findsNothing);
    });

    testWidgets('the section fits a small phone with text twice as large', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ClimateTrendsSection(
                future: Future.value(ClimateTrends.fromJson(_savedJson())),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(pl.climateSectionTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      final style = tester
          .widget<Text>(find.text(pl.climateNotForecast))
          .style!;
      expect(style.fontSize, greaterThanOrEqualTo(18));
    });

    testWidgets('the whole report fits a phone with large text', (
      tester,
    ) async {
      await _open(
        tester,
        Future.value(ClimateTrends.fromJson(_savedJson())),
        size: const Size(400, 6000),
        textScale: 1.5,
      );

      expect(find.text(en.climateSectionTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
