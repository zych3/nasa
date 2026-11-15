import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hopito_field_shift/app/app_theme.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
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
    FLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  theme: AppTheme.material(AppTheme.light),
  builder: (context, child) => FTheme(
    data: AppTheme.light,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.5)),
      child: child!,
    ),
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
  }
}
