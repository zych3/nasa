import 'package:material_ui/material_ui.dart';

import '../../models/rotation_report.dart';
import 'level_badge.dart';

class RatingRow extends StatelessWidget {
  const RatingRow({super.key, required this.label, required this.rating});

  final String label;
  final Rating rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                ),
              ),
              LevelBadge(level: rating.level),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rating.value.clamp(0.0, 1.0),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}
