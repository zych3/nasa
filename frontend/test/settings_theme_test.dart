import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/pages/settings_page.dart';
import 'package:hopito_field_shift/repositories/settings_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small app that follows [SettingsStore.themeMode], like the real one.
Widget _app(SettingsStore settings, {Brightness phone = Brightness.light}) =>
    MediaQuery(
      data: MediaQueryData(platformBrightness: phone),
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: settings.themeMode,
          home: SettingsPage(settings: settings, onLocaleChanged: (_) {}),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsStore theme', () {
    test('follows the phone until the user chooses', () async {
      final settings = SettingsStore();
      await settings.load();

      expect(settings.themeMode, ThemeMode.system);
    });

    test('the choice is saved and comes back after a restart', () async {
      await SettingsStore().setThemeMode(ThemeMode.dark);

      final again = SettingsStore();
      await again.load();

      expect(again.themeMode, ThemeMode.dark);
    });

    test('an unknown saved value falls back to the phone\'s setting', () async {
      SharedPreferences.setMockInitialValues({'settings_theme': 'purple'});
      final settings = SettingsStore();
      await settings.load();

      expect(settings.themeMode, ThemeMode.system);
    });
  });

  group('Settings page', () {
    Finder darkSwitch() => find.widgetWithText(SwitchListTile, 'Dark mode');

    testWidgets('the switch shows the look that is on screen', (tester) async {
      final settings = SettingsStore();
      await tester.pumpWidget(_app(settings, phone: Brightness.dark));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(darkSwitch()).value, isTrue);
    });

    testWidgets('turning it on switches to dark and saves it', (tester) async {
      final settings = SettingsStore();
      await tester.pumpWidget(_app(settings));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(darkSwitch()).value, isFalse);

      await tester.tap(darkSwitch());
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);
      expect(tester.widget<SwitchListTile>(darkSwitch()).value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_theme'), 'dark');
    });

    testWidgets('turning it off on a dark phone chooses light', (tester) async {
      final settings = SettingsStore();
      await tester.pumpWidget(_app(settings, phone: Brightness.dark));
      await tester.pumpAndSettle();

      await tester.tap(darkSwitch());
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.light);
      expect(tester.widget<SwitchListTile>(darkSwitch()).value, isFalse);
    });
  });
}
