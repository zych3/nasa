import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/widgets/read_aloud_button.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_speaker.dart';

Widget _app(FakeSpeaker speaker, Widget child, {Locale? locale}) => MaterialApp(
  locale: locale ?? const Locale('pl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: SpeakerScope(
    speaker: speaker,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));
  final en = lookupAppLocalizations(const Locale('en'));
  late FakeSpeaker speaker;

  setUp(() => speaker = FakeSpeaker());

  testWidgets('reads in the app language; tap again stops', (tester) async {
    await tester.pumpWidget(
      _app(speaker, ReadAloudButton(text: () => 'Gleba. Lekka.')),
    );

    await tester.tap(find.byTooltip(pl.readAloud));
    await tester.pump();
    expect(speaker.spoken, [('Gleba. Lekka.', 'pl-PL')]);
    expect(find.byTooltip(pl.readAloudStop), findsOneWidget);

    await tester.tap(find.byTooltip(pl.readAloudStop));
    await tester.pump();
    expect(speaker.stops, 1);
    expect(find.byTooltip(pl.readAloud), findsOneWidget);
  });

  testWidgets('English voice for the English app', (tester) async {
    await tester.pumpWidget(
      _app(
        speaker,
        ReadAloudButton(text: () => 'Soil.'),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.byTooltip(en.readAloud));
    expect(speaker.spoken.single.$2, 'en-GB');
  });

  testWidgets('back to "read" when the reading ends', (tester) async {
    await tester.pumpWidget(_app(speaker, ReadAloudButton(text: () => 'x')));
    await tester.tap(find.byTooltip(pl.readAloud));
    await tester.pump();

    speaker.finish();
    await tester.pump();
    expect(find.byTooltip(pl.readAloud), findsOneWidget);
  });

  testWidgets('no speech engine: a friendly message', (tester) async {
    speaker.fail = true;
    await tester.pumpWidget(_app(speaker, ReadAloudButton(text: () => 'x')));

    await tester.tap(find.byTooltip(pl.readAloud));
    await tester.pump();

    expect(find.text(pl.readAloudUnavailable), findsOneWidget);
    expect(find.byTooltip(pl.readAloud), findsOneWidget);
  });

  testWidgets('leaving the screen stops the reading', (tester) async {
    await tester.pumpWidget(_app(speaker, ReadAloudButton(text: () => 'x')));
    await tester.tap(find.byTooltip(pl.readAloud));
    await tester.pump();

    await tester.pumpWidget(_app(speaker, const SizedBox()));
    expect(speaker.stops, 1);
  });

  test('sentences get a full stop, empty parts are skipped', () {
    expect(
      sentencesForReading(['Upały', null, ' ', 'lipiec 2025', 'Koniec.']),
      'Upały. lipiec 2025. Koniec.',
    );
  });
}
