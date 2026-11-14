import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/api/api_client.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/repositories/selected_plot_store.dart';
import 'package:hopito_field_shift/screens/overlays_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  locale: const Locale('pl'),
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

void main() {
  late FakeMapLayersRepository repo;
  late SelectedPlotStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeMapLayersRepository();
    store = SelectedPlotStore();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool active = true,
    VoidCallback? onChooseField,
    double textScale = 1,
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

    // Legend below: every step, this place marked.
    await tester.scrollUntilVisible(find.text(_pl.soilClassHeavy), 100);
    expect(find.text(_pl.soilClassLight), findsNWidgets(3));
    expect(find.text(_pl.soilClassMedium), findsOneWidget);
    expect(find.text(_pl.overlaysLegendHere), findsOneWidget);
  });

  testWidgets('without a field: notice and a button to choose one', (
    tester,
  ) async {
    var chooseTaps = 0;
    await pumpScreen(tester, onChooseField: () => chooseTaps++);

    expect(find.text(_pl.overlaysNoField), findsOneWidget);
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
    // Phone in portrait and a wide browser window.
    for (final size in const [Size(360, 640), Size(1280, 800)]) {
      testWidgets('no overflow at 1.5× text in every state, $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await store.select(_parcel);
        await pumpScreen(tester, textScale: 1.5);
        expect(tester.takeException(), isNull, reason: 'loading');

        repo.fail(_parcel.center, ApiException('x'));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'error');

        await tester.scrollUntilVisible(find.text(_pl.overlaysShowDemo), 100);
        expect(tester.takeException(), isNull, reason: 'error buttons');
        await tester.tap(find.text(_pl.tryAgain));
        await tester.pump();
        repo.complete(_parcel.center, loadSample());
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'ready');
        await tester.scrollUntilVisible(find.text(_pl.soilClassHeavy), 100);
        expect(tester.takeException(), isNull, reason: 'legend');
      });
    }

    testWidgets('touch targets, labels and text contrast', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, textScale: 1.5);
      repo.complete(OverlaysScreen.examplePlace, loadSample());
      await tester.pump();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('the chosen overlay is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel(_pl.overlaySoilTitle)),
        matchesSemantics(
          label: _pl.overlaySoilTitle,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
