import 'package:material_ui/material_ui.dart';

/// Round button floating over a map or a page (language flag, my position,
/// show my field): surface colour with a shadow, so it stands out on any map.
class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.child});

  /// Diameter.
  static const size = 48.0;

  /// Gap to the screen edge when it floats in a corner.
  static const margin = 12.0;

  /// Room to leave at the end of a top line that has a floating button in the
  /// top corner (so text does not run under it).
  static const reservedEnd = size + margin + 8;

  /// Usually an `IconButton`.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Thin border and a soft, wide shadow: stands out on any map without
    // looking heavy.
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        shape: CircleBorder(side: BorderSide(color: scheme.outline)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox.square(dimension: size, child: child),
      ),
    );
  }
}

/// [child] with [button] floating in its top end corner, below the status
/// bar, like the controls of the "My area" map. No bar of its own: the page
/// reaches the top and the button sits over it.
class WithFloatingButton extends StatelessWidget {
  const WithFloatingButton({
    super.key,
    required this.button,
    required this.child,
  });

  final Widget button;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                top: MapButton.margin,
                end: MapButton.margin,
              ),
              child: MapButton(child: button),
            ),
          ),
        ),
      ],
    );
  }
}
