import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hopito_field_shift/app/app_theme.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/models/parcel_facts.dart';
import 'package:hopito_field_shift/overlays/field_conditions_controller.dart';
import 'package:hopito_field_shift/overlays/map_layers_repository.dart';
import 'package:hopito_field_shift/widgets/field_conditions_section.dart';

Map<String, dynamic> _asset(String name) =>
    jsonDecode(File('assets/mock/$name').readAsStringSync())
        as Map<String, dynamic>;

final _layers = _asset('map_layers_sample.json');
final _details = _asset('parcel_details_sample.json');

/// Answers only when the test completes the matching completer.
class _SlowRepo extends MapLayersRepository {
  var climate = Completer<Map<String, dynamic>>();
  var parcel = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> mapLayers(LatLng point, {bool refresh = false}) {
    if (refresh) climate = Completer();
    return climate.future;
  }

  @override
  Future<Map<String, dynamic>> parcelDetails(
    LatLng point, {
    String? parcelId,
    bool refresh = false,
  }) {
    if (refresh) parcel = Completer();
    return parcel.future;
  }

  @override
  Future<Map<String, dynamic>> demo() async => _layers;

  @override
  Future<Map<String, dynamic>> demoParcelDetails() async => _details;
}

const _field = Parcel(
  id: '141205_2.0008.60',
  center: LatLng(52.2, 21.48),
  ring: [LatLng(52.2, 21.48), LatLng(52.21, 21.48), LatLng(52.2, 21.49)],
);

Widget _app(
  FieldConditionsController controller, {
  Locale locale = const Locale('pl'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    FLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  theme: AppTheme.material(AppTheme.light),
  builder: (context, child) => FTheme(data: AppTheme.light, child: child!),
  home: Scaffold(
    body: SingleChildScrollView(
      child: FieldConditionsSection(controller: controller, hasField: true),
    ),
  ),
);

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  test('parcel facts from the saved real parcel details', () {
    final facts = ParcelFacts.fromJson(_details);

    expect(facts.areaHa, 0.76);
    expect(facts.landRegistry!.classes.map((c) => c.code), ['IVb', 'IVa']);
    expect(facts.soilMap!.complexName, 'kompleks żytni dobry');
    expect(facts.soilMap!.surveyYear, 1973);
    expect(facts.terrain!.level, SlopeLevel.flat);
    expect(facts.soil!.phLevel, PhLevel.slightlyAcidic);
  });

  test('a section that is not "ok" is left out', () {
    final facts = ParcelFacts.fromJson({
      'outlineAreaHa': 1.5,
      'landRegistry': {'status': 'unavailable', 'data': null},
      'terrain': {'status': 'noData', 'data': null},
    });

    expect(facts.areaHa, 1.5);
    expect(facts.landRegistry, isNull);
    expect(facts.terrain, isNull);
  });

  test('every monthly overlay reads the saved real NASA response', () {
    final conditions = FieldConditionsController.parseConditions(_layers);

    expect(
      conditions.map((c) => c.overlay.id),
      containsAll(['soilMoisture', 'precipitation', 'plantStress']),
    );
    for (final c in conditions) {
      expect(c.layer.current, isNotNull, reason: c.overlay.id);
    }
  });

  testWidgets('progress bar, then each part as it arrives', (tester) async {
    final repo = _SlowRepo();
    final controller = FieldConditionsController(repository: repo)
      ..show(_field);
    await tester.pumpWidget(_app(controller));

    expect(find.text(pl.fieldDataLoading), findsOneWidget);
    expect(find.text(pl.fieldDataLoading), findsOneWidget);

    repo.climate.complete(_layers);
    // Still loading the parcel (spinner keeps moving): pump, not settle.
    await tester.pump();
    await tester.pump();
    expect(find.text(pl.fieldConditionsHeading), findsOneWidget);
    expect(find.text(pl.overlayMoistureTitle), findsOneWidget);
    // The parcel part is still loading.
    expect(find.text(pl.fieldDataLoading), findsOneWidget);
    expect(find.text(pl.fieldFactsHeading), findsNothing);

    repo.parcel.complete(_details);
    await tester.pumpAndSettle();
    expect(find.text(pl.fieldDataLoading), findsNothing);
    expect(find.text(pl.fieldFactsHeading), findsOneWidget);
    expect(find.text(pl.fieldFactQualityClass), findsOneWidget);
  });

  testWidgets('NASA down: error, then the example data with a notice', (
    tester,
  ) async {
    final repo = _SlowRepo();
    final controller = FieldConditionsController(repository: repo)
      ..show(_field);
    await tester.pumpWidget(_app(controller));

    repo.climate.completeError(TimeoutException('NASA slow'));
    repo.parcel.completeError(TimeoutException('register slow'));
    await tester.pumpAndSettle();
    expect(find.text(pl.overlaysErrorSlow), findsOneWidget);
    expect(find.text(pl.fieldFactsNone), findsOneWidget);

    await tester.tap(find.text(pl.overlaysShowDemo));
    await tester.pumpAndSettle();
    expect(find.text(pl.overlaysDemoNotice), findsOneWidget);
    expect(find.text(pl.fieldConditionsHeading), findsOneWidget);
    expect(find.text(pl.fieldFactsHeading), findsOneWidget);
  });

  testWidgets('fits a phone at 1.5× text in both languages', (tester) async {
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final locale in AppLocalizations.supportedLocales) {
      final controller = FieldConditionsController(repository: _SlowRepo())
        ..showDemo();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 3000),
            textScaler: TextScaler.linear(1.5),
          ),
          child: _app(controller, locale: locale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });
}
