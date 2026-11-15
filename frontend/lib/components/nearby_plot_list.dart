import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/parcel.dart';

/// "12 m" / "1.4 km".
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

/// Parcels near the user as one bordered list with big tappable rows.
/// The chosen parcel gets a check mark (not only a colour).
class NearbyPlotList extends StatelessWidget {
  const NearbyPlotList({
    super.key,
    required this.parcels,
    required this.onSelected,
    this.selectedId,
  });

  final List<Parcel> parcels;
  final String? selectedId;
  final ValueChanged<Parcel> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;

    return FCard(
      clipBehavior: Clip.antiAlias,
      child: FItemGroup(
        divider: FItemDivider.indented,
        children: [
          for (final parcel in parcels)
            FItem(
              selected: parcel.id == selectedId,
              onPress: () => onSelected(parcel),
              prefix: Icon(
                parcel.id == selectedId
                    ? Icons.check_circle
                    : Icons.landscape_outlined,
                size: 28,
                color: colors.foreground,
              ),
              title: Text(
                parcel.address ?? l10n.parcelHere,
                style: type.body.md.copyWith(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                [
                  l10n.parcelNumber(parcel.id),
                  if (parcel.distanceMeters case final d?)
                    l10n.distanceFromYou(formatDistance(d)),
                ].join('  ·  '),
                style: type.body.sm.copyWith(color: colors.mutedForeground),
              ),
              suffix: Icon(Icons.chevron_right, color: colors.mutedForeground),
            ),
        ],
      ),
    );
  }
}
