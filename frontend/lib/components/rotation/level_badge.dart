import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';

/// A rating level ("good", "fair", "poor") as an icon and a word in the
/// theme's colours, never colour alone.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});

  final String level;

  /// Amber that reads on both light and dark backgrounds.
  static const _amber = Color(0xFFB26A00);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final (icon, color) = switch (level) {
      'good' => (FLucideIcons.circleCheck, colors.primary),
      'poor' => (FLucideIcons.triangleAlert, colors.error),
      _ => (FLucideIcons.circleMinus, _amber),
    };
    final text = levelLabel(AppLocalizations.of(context), level);

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.typography.body.md.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
