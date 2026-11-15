import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/rotation_report.dart';
import 'level_badge.dart';

/// One rated aspect of a plan: its name, the level in words and a thin bar.
class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.label, required this.rating});

  final String label;
  final Rating rating;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.typography.body.md.copyWith(
                    color: theme.colors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: LevelBadge(level: rating.level)),
            ],
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: FDeterminateProgress(value: rating.value.clamp(0.0, 1.0)),
          ),
        ],
      ),
    );
  }
}
