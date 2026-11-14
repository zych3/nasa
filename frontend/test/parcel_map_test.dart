import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/parcel_map.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

const _field = Parcel(
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

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('map fits a phone at 1.5× text, $locale', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l10n = lookupAppLocalizations(locale);

      await tester.pumpWidget(
        MaterialApp(
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
          home: const Scaffold(
            body: ParcelMap(myField: _field, fitMyField: true),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.myFieldMarker), findsOneWidget);
      // One credit, translated, without a doubled "©".
      expect(find.text(l10n.mapAttribution), findsOneWidget);
      expect(find.textContaining('flutter_map'), findsNothing);
    });
  }
}
