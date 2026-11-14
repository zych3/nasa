import 'package:material_ui/material_ui.dart';

/// Black or white, whichever reads better on [background] (WCAG contrast).
Color readableOn(Color background) {
  final l = background.computeLuminance();
  final onBlack = (l + 0.05) / 0.05;
  final onWhite = 1.05 / (l + 0.05);
  return onBlack >= onWhite ? Colors.black : Colors.white;
}

/// Label drawn on a map: icon (or level bars) + word on a coloured pill, in
/// black or white, whichever reads better on the colour (never colour alone).
/// Text is 18 px; give the marker room for it (about 52 px high) and clamp the
/// text scale of the marker layer, since marker boxes have a fixed size.
class MapPill extends StatelessWidget {
  const MapPill({
    super.key,
    required this.color,
    required this.text,
    required this.leading,
    this.bordered = false,
  });

  final Color color;
  final String text;

  /// Icon or level bars, drawn in the text colour.
  final Widget Function(Color onColor) leading;

  /// Outline in the text colour, so a light pill stands out on the map.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final onColor = readableOn(color);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: bordered ? Border.all(color: onColor, width: 1.5) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading(onColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
