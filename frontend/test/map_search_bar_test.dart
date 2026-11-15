import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/map_search_bar.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Future<bool> Function(String) onSearch) => MaterialApp(
  locale: const Locale('pl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: Scaffold(body: MapSearchBar(onSearch: onSearch)),
);

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  Future<void> search(WidgetTester tester, String text) async {
    await tester.tap(find.bySemanticsLabel(pl.findParcel));
    await tester.pump();
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
  }

  testWidgets('a failing search does not leave the field disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app((_) async => throw Exception('offline')));
    await search(tester, 'Warszawa, Marszałkowska 1');

    expect(tester.takeException(), isNull);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a found address closes the field', (tester) async {
    String? asked;
    await tester.pumpWidget(
      _app((address) async {
        asked = address;
        return true;
      }),
    );
    await search(tester, '  Mińsk Mazowiecki  ');

    expect(asked, 'Mińsk Mazowiecki');
    expect(find.byType(TextField), findsNothing);
  });
}
