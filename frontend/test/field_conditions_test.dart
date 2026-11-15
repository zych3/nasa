import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hopito_field_shift/app/app_theme.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/models/parcel_facts.dart';
import 'package:hopito_field_shift/models/satellite_data.dart';
import 'package:hopito_field_shift/overlays/field_conditions_controller.dart';
import 'package:hopito_field_shift/overlays/map_layers_repository.dart';
import 'package:hopito_field_shift/widgets/field_conditions_section.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> _asset(String name) =>
    jsonDecode(File('assets/mock/$name').readAsStringSync())
        as Map<String, dynamic>;

final _details = _asset('parcel_details_sample.json');
final _satellite = _asset('satellite_sample.json');

/// The parcel answers when the test completes [parcel]; satellites answer
/// at once with the saved real data, or fail when [satelliteFails].
class _Repo extends MapLayersRepository {
  var parcel = Completer<Map<String, dynamic>>();
  bool satelliteFails = false;

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
  Future<Map<String, dynamic>> satellite(
    SatellitePart part,
    LatLng point, {
    bool refresh = false,
  }) async {
    if (satelliteFails) throw TimeoutException('NASA slow');
    return _satellite[part.key] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> demoSatellite(SatellitePart part) async =>
      _satellite[part.key] as Map<String, dynamic>;

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

  testWidgets('satellites and what they mean first, the parcel when ready', (
    tester,
  ) async {
    final repo = _Repo();
    final controller = FieldConditionsController(repository: repo)
      ..show(_field);
    await tester.pumpWidget(_app(controller));
    // Parcel still loading (spinner keeps moving): pump, not settle.
    await tester.pump();
    await tester.pump();

    expect(find.text(pl.indTitle), findsOneWidget);
    expect(find.text(pl.satTitle), findsOneWidget);
    expect(find.text(pl.fieldDataLoading), findsOneWidget);
    expect(find.text(pl.fieldFactsHeading), findsNothing);
    // The monthly ~50 km card is gone from "My field".
    expect(find.text(pl.fieldConditionsHeading), findsNothing);

    repo.parcel.complete(_details);
    await tester.pumpAndSettle();
    expect(find.text(pl.fieldDataLoading), findsNothing);
    expect(find.text(pl.fieldFactsHeading), findsOneWidget);
    // The parcel's slope now takes part in the erosion estimate.
    expect(find.textContaining('Nachylenie działki'), findsWidgets);
  });

  testWidgets('NASA down: error, then the example data with a notice', (
    tester,
  ) async {
    final repo = _Repo()..satelliteFails = true;
    final controller = FieldConditionsController(repository: repo)
      ..show(_field);
    await tester.pumpWidget(_app(controller));
    repo.parcel.completeError(TimeoutException('register slow'));
    await tester.pumpAndSettle();

    expect(find.text(pl.overlaysErrorSlow), findsOneWidget);
    expect(find.text(pl.fieldFactsNone), findsOneWidget);

    await tester.ensureVisible(find.text(pl.overlaysShowDemo));
    await tester.tap(find.text(pl.overlaysShowDemo));
    await tester.pumpAndSettle();
    expect(find.text(pl.overlaysDemoNotice), findsOneWidget);
    expect(find.text(pl.indTitle), findsOneWidget);
    expect(find.text(pl.fieldFactsHeading), findsOneWidget);
  });

  testWidgets('fits a phone at 1.5× text in both languages', (tester) async {
    tester.view.physicalSize = const Size(360, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final locale in AppLocalizations.supportedLocales) {
      final controller = FieldConditionsController(repository: _Repo())
        ..showDemo();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 5000),
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
