import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hopito_field_shift/components/app_nav_bar.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/l10n/crop_note_text.dart';

/// Same localization setup as `FieldShiftApp` in main.dart.
Widget _app(Locale locale, Widget body, {Widget? bottom}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: Scaffold(body: body, bottomNavigationBar: bottom),
);

void main() {
  testWidgets('nav bar shows translated tabs and reports taps', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _app(
        const Locale('pl'),
        const SizedBox(),
        bottom: StatefulBuilder(
          builder: (context, setState) => AppNavBar(
            selectedIndex: selected,
            onSelected: (i) => setState(() => selected = i),
          ),
        ),
      ),
    );

    final pl = lookupAppLocalizations(const Locale('pl'));
    expect(find.text(pl.navMap), findsOneWidget);
    expect(find.text(pl.navPlot), findsOneWidget);
    expect(find.text(pl.navConditions), findsOneWidget);

    await tester.tap(find.text(pl.navConditions));
    await tester.pump();
    expect(selected, 2);
  });

  testWidgets('nav bar with 3 tabs fits a phone at 1.5× text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: _app(
            locale,
            const SizedBox(),
            bottom: AppNavBar(selectedIndex: 2, onSelected: (_) {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$locale');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }
  });

  testWidgets('nav bar switches language', (tester) async {
    await tester.pumpWidget(
      _app(
        const Locale('en'),
        const SizedBox(),
        bottom: AppNavBar(selectedIndex: 0, onSelected: (_) {}),
      ),
    );

    final en = lookupAppLocalizations(const Locale('en'));
    final pl = lookupAppLocalizations(const Locale('pl'));
    expect(find.text(en.navMap), findsOneWidget);
    expect(en.navMap, isNot(pl.navMap));
  });

  test('every backend note code has a translation in both languages', () {
    const codes = [
      'one_price_all_wheat',
      'one_price_all_rye',
      'one_price_all_barley',
      'grain_maize_price',
      'yearly_only',
      'grain_maize_only',
      'all_sweet_lupins',
      'no_eurostat_figure',
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      for (final code in codes) {
        expect(
          cropNoteText(l10n, code),
          isNotEmpty,
          reason: '$code in $locale',
        );
      }
      expect(cropNoteText(l10n, 'unknown_code'), isNull);
      expect(cropNoteText(l10n, null), isNull);
    }
  });
}
