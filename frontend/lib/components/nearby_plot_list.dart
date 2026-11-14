import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/parcel.dart';

/// "12 m" / "1.4 km".
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

/// Big tappable cards, one per parcel near the user.
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final parcel in parcels)
          Card(
            child: ListTile(
              minTileHeight: 72,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              selected: parcel.id == selectedId,
              leading: Icon(
                parcel.id == selectedId
                    ? Icons.check_circle
                    : Icons.landscape_outlined,
                size: 32,
              ),
              title: Text(
                parcel.address ?? l10n.parcelHere,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                [
                  l10n.parcelNumber(parcel.id),
                  if (parcel.distanceMeters case final d?)
                    l10n.distanceFromYou(formatDistance(d)),
                ].join('  •  '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelected(parcel),
            ),
          ),
      ],
    );
  }
}
