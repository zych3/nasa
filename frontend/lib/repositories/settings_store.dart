import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/language_options.dart';

/// App settings kept on the phone. Also read by the weekly frost check, which
/// runs without the app, so the values live in shared_preferences.
class SettingsStore extends ChangeNotifier {
  static const _frostKey = 'settings_frost_alerts';
  static const _languageKey = 'settings_language';
  static const _themeKey = 'settings_theme';

  bool _frostAlerts = true;
  Locale _locale = defaultLocale;
  ThemeMode _themeMode = ThemeMode.system;

  bool get frostAlerts => _frostAlerts;
  Locale get locale => _locale;

  /// Light or dark; follows the phone until the user picks one.
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _frostAlerts = prefs.getBool(_frostKey) ?? true;
      final code = prefs.getString(_languageKey);
      if (code != null) _locale = Locale(code);
      _themeMode = switch (prefs.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Settings are a convenience; start with the defaults.
    }
    notifyListeners();
  }

  /// Language chosen in the settings; defaults when none was saved.
  static Future<Locale> savedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_languageKey);
      return code == null ? defaultLocale : Locale(code);
    } catch (_) {
      return defaultLocale;
    }
  }

  /// Whether alerts are on, read straight from disk (for the background task).
  static Future<bool> savedFrostAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(_frostKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setFrostAlerts(bool value) async {
    _frostAlerts = value;
    notifyListeners();
    await _save((p) => p.setBool(_frostKey, value));
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _save((p) => p.setString(_languageKey, locale.languageCode));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _save((p) => p.setString(_themeKey, mode.name));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Keep the choice for this session even if it cannot be saved.
    }
  }
}
