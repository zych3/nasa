import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Plain text credit required by OpenStreetMap, in the bottom right corner of
/// a map (put it last in `FlutterMap.children`).
///
/// Not flutter_map's `SimpleAttributionWidget`: that one keeps its text in a
/// `Row`, so it overflows on a phone with large system text, and it adds its
/// own "©" in front of ours.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: scheme.surface.withValues(alpha: 0.85),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            AppLocalizations.of(context).mapAttribution,
            style: TextStyle(color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
