import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/map_search_bar.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/address_suggestion.dart';
import 'package:hopito_field_shift/repositories/parcel_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

/// Hints without a backend: a town for "Wiel", then a street, then a house.
class _FakeRepo extends ParcelRepository {
  final asked = <String>[];

  @override
  Future<List<AddressSuggestion>> suggest(String text) async {
    asked.add(text);
    const point = LatLng(49.98, 20.05);
    if (!text.contains(',')) {
      return const [
        AddressSuggestion(
          kind: AddressSuggestionKind.place,
          point: point,
          city: 'Wieliczka',
          area: ['wielicki', 'małopolskie'],
        ),
      ];
    }
    return const [
      AddressSuggestion(
        kind: AddressSuggestionKind.address,
        point: point,
        city: 'Wieliczka',
        street: 'Krakowska',
        number: '1',
        postalCode: '32-020',
      ),
    ];
  }
}

Widget _app(
  Future<bool> Function(String) onSearch, {
  Future<bool> Function(AddressSuggestion)? onAddressChosen,
  ParcelRepository? repository,
}) => MaterialApp(
  locale: const Locale('pl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: Scaffold(
    body: MapSearchBar(
      onSearch: onSearch,
      onAddressChosen: onAddressChosen ?? (_) async => false,
      repository: repository ?? _FakeRepo(),
    ),
  ),
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

  testWidgets('hints: town, then a full address that goes to the parcel', (
    tester,
  ) async {
    final repo = _FakeRepo();
    AddressSuggestion? chosen;
    await tester.pumpWidget(
      _app(
        (_) async => false,
        repository: repo,
        onAddressChosen: (hint) async {
          chosen = hint;
          return true;
        },
      ),
    );

    await tester.tap(find.bySemanticsLabel(pl.findParcel));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Wiel');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Wieliczka'), findsOneWidget);

    // A town fills the field ("Wieliczka, ") and asks for streets.
    await tester.tap(find.text('Wieliczka'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(repo.asked.last, 'Wieliczka,');
    expect(find.text('Krakowska 1'), findsOneWidget);

    // A full address goes there and closes the search.
    await tester.tap(find.text('Krakowska 1'));
    await tester.pumpAndSettle();
    expect(chosen?.number, '1');
    expect(find.byType(TextField), findsNothing);
  });
}
