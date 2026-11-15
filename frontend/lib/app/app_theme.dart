import 'package:material_ui/material_ui.dart';

/// The app's colours: a dark field green as the main colour and a fresher
/// green as the accent, in a light and a dark version. Colours that carry
/// meaning (good / ok / poor ratings, map layers) are set where they are used.
abstract final class AppTheme {
  static const _darkGreen = Color(0xFF1B5E20);
  static const _green = Color(0xFF43A047);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final main = ColorScheme.fromSeed(
      seedColor: _darkGreen,
      brightness: brightness,
    );
    // The accent roles come from the lighter green, so cards and chips that
    // use them are visibly green too, not the muted grey-green of the seed.
    final accent = ColorScheme.fromSeed(
      seedColor: _green,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: main.copyWith(
        secondary: accent.primary,
        onSecondary: accent.onPrimary,
        secondaryContainer: accent.primaryContainer,
        onSecondaryContainer: accent.onPrimaryContainer,
      ),
    );
  }
}
