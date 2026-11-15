import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/crop_details_sheet.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:hopito_field_shift/models/trending_crop.dart';
import 'package:hopito_field_shift/pages/plot_page.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/selected_plot_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(1.5)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

const _field = Parcel(
  id: '146501_8.0001.123',
  center: LatLng(52.21, 21.49),
  address: 'Mińsk Mazowiecki, ul. Warszawska 1',
  distanceMeters: 1420,
  ring: [
    LatLng(52.209, 21.489),
    LatLng(52.209, 21.491),
    LatLng(52.211, 21.491),
    LatLng(52.209, 21.489),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // Crop photos go through a disk cache that asks path_provider for a folder;
  // tests have no such plugin, so give it a temporary one.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.createTempSync('crop_img').path,
        );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('My field fits a phone at 1.5× text, $locale', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = SelectedPlotStore();
      await store.select(_field);
      store.setNearby(const [_field]);

      await tester.pumpWidget(
        _app(PlotPage(store: store, authStore: AuthStore()), locale),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scrolled $i');
      }
    });

    testWidgets('Crop details fit a phone at 1.5× text, $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l10n = lookupAppLocalizations(locale);
      final raw = File('assets/mock/trends_${locale.languageCode}.json')
          .readAsStringSync();
      final crops = (jsonDecode(raw) as Map<String, dynamic>)['crops'] as List;

      for (final item in crops) {
        final crop = TrendingCrop.fromJson(item as Map<String, dynamic>);
        // A fresh sheet per crop, as in the app (each one is a new route).
        await tester.pumpWidget(
          _app(CropDetailsSheet(key: ValueKey(crop.id), crop: crop), locale),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: crop.id);
        // Scroll to the end in steps, checking every step.
        await tester.scrollUntilVisible(
          find.text(l10n.close),
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        expect(tester.takeException(), isNull, reason: crop.id);
        expect(find.text(l10n.close), findsOneWidget, reason: crop.id);
      }
      // Network timeouts (10 s) of the photos and prices run on the test's
      // fake clock: let them end before the test does.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
    });
  }
}
