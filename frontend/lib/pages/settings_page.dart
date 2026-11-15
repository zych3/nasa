import 'package:material_ui/material_ui.dart';

import '../components/language_flag_button.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language_options.dart';
import '../repositories/settings_store.dart';

/// Settings: the language, light or dark mode and the frost alerts.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.onLocaleChanged,
  });

  final SettingsStore settings;
  final ValueChanged<Locale> onLocaleChanged;

  static String languageName(Locale locale) => switch (locale.languageCode) {
    'pl' => 'Polski',
    'en' => 'English',
    final code => code.toUpperCase(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l10n.settingsLanguage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RadioGroup<String>(
                groupValue: settings.locale.languageCode,
                onChanged: (code) {
                  if (code == null) return;
                  final locale = Locale(code);
                  settings.setLocale(locale);
                  onLocaleChanged(locale);
                },
                child: Column(
                  children: [
                    for (final locale in switchableLocales)
                      RadioListTile<String>(
                        value: locale.languageCode,
                        secondary: LanguageFlag(
                          languageCode: locale.languageCode,
                        ),
                        title: Text(languageName(locale)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),
              SwitchListTile(
                // What is on screen now, also while the app follows the phone.
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (dark) => settings.setThemeMode(
                  dark ? ThemeMode.dark : ThemeMode.light,
                ),
                title: Text(l10n.settingsDarkMode),
                subtitle: Text(l10n.settingsDarkModeHint),
                secondary: const Icon(Icons.dark_mode_outlined),
              ),
              SwitchListTile(
                value: settings.frostAlerts,
                onChanged: settings.setFrostAlerts,
                title: Text(l10n.settingsFrostAlerts),
                subtitle: Text(l10n.settingsFrostAlertsHint),
                secondary: const Icon(Icons.ac_unit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
