import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/repositories/selected_plot_store.dart';
import 'package:hopito_field_shift/screens/overlays_screen.dart';
import 'package:hopito_field_shift/widgets/read_aloud_button.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_speaker.dart';
import 'fake_map_layers_repository.dart';
import 'sample.dart';

final _pl = lookupAppLocalizations(const Locale('pl'));

const _parcel = Parcel(
  id: '146501_8.0001.123',
  center: LatLng(52.21, 21.49),
  ring: [
    LatLng(52.209, 21.489),
    LatLng(52.209, 21.491),
    LatLng(52.211, 21.491),
    LatLng(52.211, 21.489),
    LatLng(52.209, 21.489),
  ],
);

Widget _app(
  Widget child, {
  double textScale = 1,
  Locale locale = const Locale('pl'),
}) => MaterialApp(
  locale: locale,
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
  home: Scaffold(body: child),
);

/// Opens the overlay list and picks [title].
Future<void> chooseOverlay(
  WidgetTester tester,
  AppLocalizations l10n,
  String title,
) async {
  await tester.ensureVisible(find.text(l10n.overlaysChange));
  await tester.pump();
  await tester.tap(find.text(l10n.overlaysChange));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}

void main() {
  late FakeMapLayersRepository repo;
  late SelectedPlotStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeMapLayersRepository()..answerGridAtOnce = true;
    store = SelectedPlotStore();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool active = true,
    VoidCallback? onChooseField,
    double textScale = 1,
    Locale locale = const Locale('pl'),
  }) async {
    await tester.pumpWidget(
      _app(
        OverlaysScreen(
          store: store,
          repository: repo,
          active: active,
          onChooseField: onChooseField,
        ),
        textScale: textScale,
        locale: locale,
      ),
    );
  }

  testWidgets('loads the example place, then shows the soil value', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(repo.requests, [OverlaysScreen.examplePlace]);
    expect(find.text(_pl.overlaysLoading), findsOneWidget);

    repo.complete(OverlaysScreen.examplePlace, loadSample());
    await tester.pump();

    // The label on the map and the value card.
    expect(find.text(_pl.soilClassLight), findsNWidgets(2));
    expect(find.text(_pl.sourceEstimated), findsOneWidget);
    expect(
      find.text(_pl.overlaysSource('ISRIC SoilGrids v2.0 (0–30 cm)')),
      findsOneWidget,
    );
    // No field chosen: the value is clearly for the example place.
    expect(find.text(_pl.overlaysValueHeadingExample), findsOneWidget);
    expect(find.text(_pl.overlaysValueHeading), findsNothing);

    // Legend below: every step, this place marked.
    await tester.scrollUntilVisible(find.text(_pl.soilClassHeavy), 100);
    expect(find.text(_pl.soilClassLight), findsNWidgets(3));
    expect(find.text(_pl.soilClassMedium), findsOneWidget);
    expect(find.text(_pl.overlaysLegendHere), findsOneWidget);
  });

  testWidgets('switching to soil moisture needs no new request', (
    tester,
  ) async {
    await pumpScreen(tester);
    repo.complete(OverlaysScreen.examplePlace, loadSample());
    await tester.pump();

    await chooseOverlay(tester, _pl, _pl.overlayMoistureTitle);

    // Backend label on the map and in the value card, month, NASA source.
    expect(find.text('umiarkowanie sucho (0,35–0,45)'), findsNWidgets(2));
    expect(find.text('grudzień 2025'), findsOneWidget);
    expect(find.bySemanticsLabel(_pl.overlaysMonth('grudzień 2025')), findsOne);

    // One month back: the value and the month change, still no request.
    await tester.tap(find.byTooltip(_pl.overlaysEarlierMonth));
    await tester.pump();
    expect(find.text('listopad 2025'), findsOneWidget);
    expect(find.text(_pl.overlaysSource('NASA POWER (GWETROOT)')), findsOne);
    expect(find.text(_pl.sourceEstimated), findsNothing);
    expect(repo.requests, hasLength(1));
  });

  testWidgets('NASA overlays: heat map instead of the circle; soil keeps it', (
    tester,
  ) async {
    repo.answerGridAtOnce = false;
    await pumpScreen(tester);
    repo.complete(OverlaysScreen.examplePlace, loadSample());
    repo.completeGrid(OverlaysScreen.examplePlace, loadGridSample());
    await tester.pump();

    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(OverlayImageLayer), findsNothing);

    await chooseOverlay(tester, _pl, _pl.overlayMoistureTitle);
    expect(find.byType(OverlayImageLayer), findsOneWidget);
    expect(find.byType(CircleLayer), findsNothing);
    // The value label stays on the map (never colour alone).
    expect(find.text('umiarkowanie sucho (0,35–0,45)'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text(_pl.overlayHeatmapNote), 100);
    expect(find.text(_pl.overlayHeatmapNote), findsOneWidget);
    expect(repo.gridRequests, [OverlaysScreen.examplePlace]);
  });

  testWidgets('while the heat map loads the map says so; on failure a circle', (
    tester,
  ) async {
    repo.answerGridAtOnce = false;
    await pumpScreen(tester);
    repo.complete(OverlaysScreen.examplePlace, loadSample());
    await tester.pump();
    // Soil has no heat map: nothing to wait for.
    expect(find.text(_pl.overlaysHeatmapLoading), findsNothing);

    // The spinner never settles, so the list is opened frame by frame.
    await tester.tap(find.text(_pl.overlaysChange));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text(_pl.overlayMoistureTitle).last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(_pl.overlayMoistureTitle).last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_pl.overlaysHeatmapLoading), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);

    repo.failGrid(OverlaysScreen.examplePlace, Exception('offline'));
    await tester.pump();
    expect(find.text(_pl.overlaysHeatmapLoading), findsNothing);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.text(_pl.overlayHeatmapNote), findsNothing);
  });

  testWidgets('reads the value card aloud', (tester) async {
    final speaker = FakeSpeaker();
    await tester.pumpWidget(
      SpeakerScope(
        speaker: speaker,
        child: _app(OverlaysScreen(store: store, repository: repo)),
      ),
    );
    repo.complete(OverlaysScreen.examplePlace, loadSample());
    await tester.pump();

    await tester.tap(find.byTooltip(_pl.readAloud));
    final (text, language) = speaker.spoken.single;
    expect(language, 'pl-PL');
    for (final part in [
      _pl.overlaySoilTitle,
      _pl.overlaysValueHeadingExample,
      _pl.soilClassLight,
      _pl.sourceEstimated,
      _pl.overlaysSource('ISRIC SoilGrids v2.0 (0–30 cm)'),
      _pl.overlayCoverageSoil,
    ]) {
      expect(text, contains(part));
    }
  });

  testWidgets('screen title only on a wide screen', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    tester.view.physicalSize = const Size(360, 640);
    await pumpScreen(tester);
    expect(find.text(_pl.overlaysTitle), findsNothing);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    expect(find.text(_pl.overlaysTitle), findsOneWidget);
  });

  testWidgets('without a field: notice and a button to choose one', (
    tester,
  ) async {
    var chooseTaps = 0;
    await pumpScreen(tester, onChooseField: () => chooseTaps++);

    expect(find.text(_pl.overlaysNoField), findsOneWidget);
    await tester.ensureVisible(find.text(_pl.overlaysChooseField));
    await tester.pump();
    await tester.tap(find.text(_pl.overlaysChooseField));
    expect(chooseTaps, 1);
  });

  testWidgets('centres on the chosen field and follows a new choice', (
    tester,
  ) async {
    await store.select(_parcel);
    await pumpScreen(tester);

    expect(repo.requests, [_parcel.center]);
    expect(find.text(_pl.overlaysNoField), findsNothing);
    repo.complete(_parcel.center, loadSample());
    await tester.pump();
    expect(find.text(_pl.overlaysValueHeading), findsOneWidget);
    expect(find.text(_pl.myFieldMarker), findsOneWidget);

    const moved = LatLng(50.06, 19.94);
    await store.select(
      Parcel(id: 'other', center: moved, ring: const [moved, moved, moved]),
    );
    await tester.pump();
    expect(repo.requests, [_parcel.center, moved]);
  });

  testWidgets('loads nothing until the tab is shown', (tester) async {
    await pumpScreen(tester, active: false);
    expect(repo.requests, isEmpty);

    await pumpScreen(tester, active: true);
    expect(repo.requests, hasLength(1));
  });

  testWidgets('network error: friendly message, retry and example data', (
    tester,
  ) async {
    await pumpScreen(tester);
    repo.fail(OverlaysScreen.examplePlace, ApiException('x'));
    await tester.pump();

    expect(find.text(_pl.overlaysErrorServer), findsOneWidget);
    expect(find.text(_pl.tryAgain), findsOneWidget);

    await tester.ensureVisible(find.text(_pl.overlaysShowDemo));
    await tester.pump();
    await tester.tap(find.text(_pl.overlaysShowDemo));
    await tester.pump();
    expect(find.text(_pl.overlaysDemoNotice), findsOneWidget);

    // From the demo the user can still ask for the real data.
    await tester.ensureVisible(find.text(_pl.tryAgain));
    await tester.pump();
    await tester.tap(find.text(_pl.tryAgain));
    await tester.pump();
    expect(repo.requests, hasLength(2));
    expect(find.text(_pl.overlaysLoading), findsOneWidget);
  });

  group('accessibility', () {
    Future<void> checkGuidelines(WidgetTester tester, String state) async {
      expect(tester.takeException(), isNull, reason: 'overflow: $state');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    // Phone in portrait and a wide browser window, both languages: no
    // overflow at 1.5× text, 48 dp targets, labels and contrast in every
    // state.
    for (final locale in AppLocalizations.supportedLocales) {
      for (final size in const [Size(360, 640), Size(1280, 800)]) {
        testWidgets('1.5× text, every state, $locale, $size', (tester) async {
          final l10n = lookupAppLocalizations(locale);
          final handle = tester.ensureSemantics();
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await pumpScreen(tester, textScale: 1.5, locale: locale);
          await checkGuidelines(tester, 'loading, no field');

          repo.fail(OverlaysScreen.examplePlace, ApiException('x'));
          await tester.pump();
          await checkGuidelines(tester, 'error');
          await tester.scrollUntilVisible(
            find.text(l10n.overlaysShowDemo),
            100,
          );
          await checkGuidelines(tester, 'error buttons');

          await tester.tap(find.text(l10n.overlaysShowDemo));
          await tester.pump();
          await checkGuidelines(tester, 'demo');

          await tester.scrollUntilVisible(find.text(l10n.tryAgain), -100);
          await tester.tap(find.text(l10n.tryAgain));
          await tester.pump();
          repo.complete(OverlaysScreen.examplePlace, loadSample());
          await tester.pump();
          await checkGuidelines(tester, 'ready');

          await tester.scrollUntilVisible(find.text(l10n.soilClassHeavy), 100);
          await checkGuidelines(tester, 'legend');
          handle.dispose();
        });
      }
    }

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('monthly overlay with month buttons, phone 1.5×, $locale', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(locale);
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pumpScreen(tester, textScale: 1.5, locale: locale);
        repo.complete(OverlaysScreen.examplePlace, loadSample());
        await tester.pump();
        await chooseOverlay(tester, l10n, l10n.overlayMoistureTitle);
        await tester.scrollUntilVisible(
          find.byTooltip(l10n.overlaysEarlierMonth),
          100,
        );
        await checkGuidelines(tester, 'month buttons');
        await tester.tap(find.byTooltip(l10n.overlaysEarlierMonth));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text(l10n.overlaysLegendHere),
          100,
        );
        await checkGuidelines(tester, 'legend');
        handle.dispose();
      });
    }

    testWidgets('chooser: one button; the list marks the chosen overlay', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, textScale: 1.5);
      repo.complete(OverlaysScreen.examplePlace, loadSample());
      await tester.pump();

      // The button says what is shown and that it can be changed.
      expect(
        find.bySemanticsLabel(
          RegExp(
            '${_pl.overlaySoilTitle}.*${_pl.overlaysChange}',
            dotAll: true,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(_pl.overlaysChange));
      await tester.pumpAndSettle();
      await checkGuidelines(tester, 'chooser sheet');
      // Exact labels: the chooser button itself reads "Gleba Zmień".
      final rows = [
        for (final title in [_pl.overlaySoilTitle, _pl.overlayMoistureTitle])
          tester.getSemantics(find.bySemanticsLabel(title)),
      ];
      expect(
        rows[0],
        matchesSemantics(
          label: _pl.overlaySoilTitle,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        rows[1],
        matchesSemantics(
          label: _pl.overlayMoistureTitle,
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
