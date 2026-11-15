import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

/// Gives a page the forui look (neutral theme, light or dark like the rest of
/// the app). Material widgets inside (text fields, cards, progress bars)
/// get matching colours and thin borders, so both kinds of
/// widgets look like one design.
class ForuiPageTheme extends StatelessWidget {
  const ForuiPageTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FTheme(
      data: dark ? FTheme.neutral.dark.touch : FTheme.neutral.light.touch,
      child: Builder(
        builder: (context) => Theme(
          data: _matchForui(Theme.of(context), context.theme.colors),
          child: child,
        ),
      ),
    );
  }
}

ThemeData _matchForui(ThemeData base, FColors c) {
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.background,
      border: outline(c.border),
      enabledBorder: outline(c.border),
      focusedBorder: outline(c.foreground, 1.5),
      prefixIconColor: c.mutedForeground,
      suffixIconColor: c.foreground,
      hintStyle: TextStyle(color: c.mutedForeground),
      helperStyle: TextStyle(color: c.mutedForeground),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.foreground,
      linearTrackColor: c.muted,
    ),
  );
}
