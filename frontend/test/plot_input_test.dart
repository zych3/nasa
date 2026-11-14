import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/input/plotInput/plot_data.dart';
import 'package:hopito_field_shift/components/input/plotInput/plot_input.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('pl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  testWidgets('no "Save" button when nothing would be saved', (tester) async {
    await tester.pumpWidget(_app(PlotInput(onFindParcel: (_) {})));
    expect(find.text(pl.submitPlot), findsNothing);
  });

  testWidgets('"Save" button when there is a handler', (tester) async {
    PlotData? saved;
    await tester.pumpWidget(_app(PlotInput(onSubmitPlot: (d) => saved = d)));
    expect(find.text(pl.submitPlot), findsOneWidget);
    expect(saved, isNull);
  });
}
