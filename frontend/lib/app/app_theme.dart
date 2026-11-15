import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// The app's look: forui (touch sizes, body text 18 px) with a field-green
/// palette, plus a matching Material theme so the Material widgets that are
/// still used (maps, sheets, text fields) look like one design.
abstract final class AppTheme {
  static final FColors lightColors = FColors(
    brightness: Brightness.light,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    barrier: const Color(0x33000000),
    background: const Color(0xFFF7F8F4),
    foreground: const Color(0xFF14201A),
    primary: const Color(0xFF1F6F3F),
    primaryForeground: const Color(0xFFFFFFFF),
    secondary: const Color(0xFFE8F0E4),
    secondaryForeground: const Color(0xFF173823),
    muted: const Color(0xFFEDF1EA),
    mutedForeground: const Color(0xFF55655A),
    destructive: const Color(0xFFC62828),
    destructiveForeground: const Color(0xFFFFFFFF),
    error: const Color(0xFFC62828),
    errorForeground: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    border: const Color(0xFFD9E2D5),
  );

  static final FColors darkColors = FColors(
    brightness: Brightness.dark,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    barrier: const Color(0x7A000000),
    background: const Color(0xFF0E1511),
    foreground: const Color(0xFFEEF4EF),
    primary: const Color(0xFF7BCB97),
    primaryForeground: const Color(0xFF0B1F12),
    secondary: const Color(0xFF1D2A22),
    secondaryForeground: const Color(0xFFE6EFE8),
    muted: const Color(0xFF1D2A22),
    mutedForeground: const Color(0xFFA9BAAE),
    destructive: const Color(0xFFFF7B7B),
    destructiveForeground: const Color(0xFF1A0505),
    error: const Color(0xFFFF7B7B),
    errorForeground: const Color(0xFF1A0505),
    card: const Color(0xFF141E18),
    border: const Color(0x26FFFFFF),
  );

  static final FThemeData light = FThemeData(
    touch: true,
    debugLabel: 'FieldShift Light',
    colors: lightColors,
  );

  static final FThemeData dark = FThemeData(
    touch: true,
    debugLabel: 'FieldShift Dark',
    colors: darkColors,
  );

  static FThemeData of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Material theme matching [theme].
  static ThemeData material(FThemeData theme) {
    final c = theme.colors;
    final base = theme.toApproximateMaterialTheme();

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      colorScheme: base.colorScheme.copyWith(
        surface: c.card,
        surfaceContainerLowest: c.background,
        surfaceContainerLow: c.background,
        surfaceContainer: c.muted,
        surfaceContainerHigh: c.muted,
        surfaceContainerHighest: c.secondary,
        primaryContainer: c.secondary,
        onPrimaryContainer: c.secondaryForeground,
        outline: c.border,
        outlineVariant: c.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        border: outline(c.border),
        enabledBorder: outline(c.border),
        focusedBorder: outline(c.primary, 2),
        errorBorder: outline(c.error),
        focusedErrorBorder: outline(c.error, 2),
        prefixIconColor: c.mutedForeground,
        suffixIconColor: c.foreground,
        hintStyle: TextStyle(color: c.mutedForeground),
        helperStyle: TextStyle(color: c.mutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          minimumSize: const Size(48, 52),
          textStyle: theme.typography.body.md.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          minimumSize: const Size(48, 52),
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.secondary,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.foreground,
        contentTextStyle: theme.typography.body.md.copyWith(
          color: c.background,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.mutedForeground,
        minTileHeight: 56,
      ),
    );
  }
}
