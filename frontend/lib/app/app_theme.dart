import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// The app's look: forui (touch sizes, Inter, body text 18 px) with a calm
/// "paper and forest" palette: warm off-white, thin borders instead of
/// shadows, one deep green accent. The Material theme is derived from it, so
/// the Material widgets that are still used (maps, sheets, text fields,
/// app bars) look like the same design.
abstract final class AppTheme {
  static final FColors lightColors = FColors(
    brightness: Brightness.light,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    barrier: const Color(0x33000000),
    background: const Color(0xFFF7F7F4),
    foreground: const Color(0xFF171A16),
    primary: const Color(0xFF2D5A3D),
    primaryForeground: const Color(0xFFFFFFFF),
    secondary: const Color(0xFFECEFE8),
    secondaryForeground: const Color(0xFF1F3527),
    muted: const Color(0xFFF0F1EC),
    mutedForeground: const Color(0xFF5F655B),
    destructive: const Color(0xFFB42318),
    destructiveForeground: const Color(0xFFFFFFFF),
    error: const Color(0xFFB42318),
    errorForeground: const Color(0xFFFFFFFF),
    card: const Color(0xFFFFFFFF),
    border: const Color(0xFFE3E4DE),
  );

  static final FColors darkColors = FColors(
    brightness: Brightness.dark,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    barrier: const Color(0x7A000000),
    background: const Color(0xFF0E100E),
    foreground: const Color(0xFFF2F4F0),
    primary: const Color(0xFF9CC7A6),
    primaryForeground: const Color(0xFF0F2416),
    secondary: const Color(0xFF222722),
    secondaryForeground: const Color(0xFFE8EDE6),
    muted: const Color(0xFF1B1F1B),
    mutedForeground: const Color(0xFFA9B0A6),
    destructive: const Color(0xFFF97066),
    destructiveForeground: const Color(0xFF1A0505),
    error: const Color(0xFFF97066),
    errorForeground: const Color(0xFF1A0505),
    card: const Color(0xFF161916),
    border: const Color(0x1FFFFFFF),
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

  /// Corner radius of cards and sheets.
  static const double radius = 16;

  /// Material theme matching [theme].
  static ThemeData material(FThemeData theme) {
    final c = theme.colors;
    final type = theme.typography;
    final base = theme.toApproximateMaterialTheme();
    final dark = c.brightness == Brightness.dark;

    // The bridge sets every line height to 1; real text needs room to
    // breathe (and wraps over several lines at large text sizes).
    TextStyle? airy(TextStyle? s, {FontWeight? weight}) =>
        s?.copyWith(height: 1.35, fontWeight: weight);
    final text = base.textTheme;
    final textTheme = text.copyWith(
      headlineLarge: airy(text.headlineLarge, weight: FontWeight.w600),
      headlineMedium: airy(text.headlineMedium, weight: FontWeight.w600),
      headlineSmall: airy(text.headlineSmall, weight: FontWeight.w600),
      titleLarge: airy(text.titleLarge, weight: FontWeight.w600),
      titleMedium: airy(text.titleMedium, weight: FontWeight.w600),
      titleSmall: airy(text.titleSmall, weight: FontWeight.w600),
      bodyLarge: airy(text.bodyLarge),
      bodyMedium: airy(text.bodyMedium),
      bodySmall: airy(text.bodySmall),
      labelLarge: airy(text.labelLarge, weight: FontWeight.w600),
      labelMedium: airy(text.labelMedium),
      labelSmall: airy(text.labelSmall),
    );

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    final rounded12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final buttonText = type.body.md.copyWith(fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: base.colorScheme.copyWith(
        surface: c.card,
        onSurface: c.foreground,
        onSurfaceVariant: c.mutedForeground,
        surfaceContainerLowest: c.background,
        surfaceContainerLow: c.background,
        surfaceContainer: c.muted,
        surfaceContainerHigh: c.muted,
        surfaceContainerHighest: c.secondary,
        primaryContainer: c.secondary,
        onPrimaryContainer: c.secondaryForeground,
        tertiary: c.primary,
        errorContainer: dark
            ? const Color(0xFF3A1714)
            : const Color(0xFFFCEDEB),
        onErrorContainer: dark
            ? const Color(0xFFFFD9D4)
            : const Color(0xFF7A1A12),
        outline: c.border,
        outlineVariant: c.border,
        shadow: Colors.black,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.display.lg.copyWith(
          fontWeight: FontWeight.w600,
          color: c.foreground,
        ),
        shape: Border(bottom: BorderSide(color: c.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        border: outline(c.border),
        enabledBorder: outline(c.border),
        focusedBorder: outline(c.primary, 1.5),
        errorBorder: outline(c.error),
        focusedErrorBorder: outline(c.error, 1.5),
        prefixIconColor: c.mutedForeground,
        suffixIconColor: c.foreground,
        labelStyle: TextStyle(color: c.mutedForeground),
        hintStyle: TextStyle(color: c.mutedForeground),
        helperStyle: TextStyle(color: c.mutedForeground),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.secondary,
        circularTrackColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          minimumSize: const Size(48, 52),
          textStyle: buttonText,
          shape: rounded12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          minimumSize: const Size(48, 52),
          textStyle: buttonText,
          shape: rounded12,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          backgroundColor: c.card,
          minimumSize: const Size(48, 52),
          textStyle: buttonText,
          side: BorderSide(color: c.border),
          shape: rounded12,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(48, 48),
          textStyle: buttonText,
          shape: rounded12,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.foreground,
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.secondary,
        side: BorderSide(color: c.border),
        labelStyle: type.body.sm.copyWith(color: c.foreground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.foreground,
        contentTextStyle: type.body.md.copyWith(color: c.background),
        actionTextColor: c.background,
        shape: rounded12,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.mutedForeground,
        minTileHeight: 56,
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: c.foreground),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: c.mutedForeground,
        ),
      ),
      // Light theme: the default "off" switch (pale track, pale outline) is
      // hard to see on the off-white background, so it gets a darker outline
      // and thumb; "on" is solid green with a white thumb.
      switchTheme: dark
          ? null
          : SwitchThemeData(
              trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? c.primary
                    : const Color(0xFFDDE0D8),
              ),
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? c.primary
                    : const Color(0xFF5F655B),
              ),
              trackOutlineWidth: const WidgetStatePropertyAll(2),
              thumbColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? Colors.white
                    : const Color(0xFF5F655B),
              ),
            ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.secondary,
        elevation: 0,
      ),
    );
  }
}
