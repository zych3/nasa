import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rotation_text.dart';

class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (level) {
      'good' => (Icons.check_circle, Colors.green.shade800),
      'poor' => (Icons.warning_amber_rounded, Colors.red.shade800),
      _ => (Icons.remove_circle_outline, Colors.orange.shade900),
    };
    final text = levelLabel(AppLocalizations.of(context), level);

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
