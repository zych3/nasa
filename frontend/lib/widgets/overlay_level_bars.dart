import 'package:material_ui/material_ui.dart';

/// "Level 2 of 4" drawn as rising bars, so a step of a scale can be told
/// apart without its colour (next to its word, never instead of it).
/// Hidden from screen readers: the word next to it says the same.
class OverlayLevelBars extends StatelessWidget {
  const OverlayLevelBars({
    super.key,
    required this.level,
    required this.count,
    required this.color,
    this.height = 22,
  }) : assert(level >= 1 && level <= count);

  /// 1-based level.
  final int level;
  final int count;

  /// Colour of the filled bars (the empty ones are outlined in it).
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final barWidth = height / 3.5;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 1; i <= count; i++) ...[
              if (i > 1) SizedBox(width: barWidth / 2),
              Container(
                width: barWidth,
                height: height * (0.35 + 0.65 * i / count),
                decoration: BoxDecoration(
                  color: i <= level ? color : null,
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
