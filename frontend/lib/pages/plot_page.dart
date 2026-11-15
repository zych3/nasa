import 'package:material_ui/material_ui.dart';

import '../components/address_search_field.dart';
import '../components/input/plotInput/plot_input.dart';
import '../components/map_button.dart';
import '../components/nearby_plot_list.dart';
import '../components/parcel_map.dart';
import '../l10n/app_localizations.dart';
import '../models/address_suggestion.dart';
import '../models/parcel.dart';
import '../repositories/parcel_repository.dart';
import '../repositories/selected_plot_store.dart';
import 'rotation_wizard_page.dart';

/// "Moje pole" – plot data page. Shows the chosen (saved) parcel and lets the
/// user pick another one from the parcels nearby or by typing an address.
class PlotPage extends StatefulWidget {
  const PlotPage({super.key, required this.store});

  final SelectedPlotStore store;

  @override
  State<PlotPage> createState() => _PlotPageState();
}

class _PlotPageState extends State<PlotPage> {
  final _parcels = ParcelRepository();
  bool _loading = false;

  Future<void> _findParcel(String address) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final parcel = await _parcels.searchByAddress(address);
      if (!mounted) return;
      if (parcel != null) {
        await widget.store.select(parcel.withAddress(address));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.parcelNotFound)));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.parcelLookupFailed)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The user picked a full address from the hints: take the parcel there.
  Future<void> _choosePoint(AddressSuggestion hint, String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final parcel = await _parcels.parcelAt(hint.point);
      if (!mounted) return;
      if (parcel != null) {
        await widget.store.select(parcel.withAddress(text));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.parcelNotFound)));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.parcelLookupFailed)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final Parcel? parcel = widget.store.parcel;
    final nearby = widget.store.nearby;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Address search with hints, at the very top. Room on the right for
        // the language button floating in the top corner.
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: MapButton.reservedEnd - 16,
          ),
          child: AddressSearchField(
            onAddressChosen: _choosePoint,
            onSearch: _findParcel,
          ),
        ),
        const SizedBox(height: 16),

        // Header: plot name, area, location
        Card(
          child: ListTile(
            leading: const Icon(Icons.agriculture, size: 40),
            title: Text(
              parcel?.address ?? '—',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Map: highlighted parcel once found, placeholder before that
        SizedBox(
          height: 280,
          child: parcel != null
              ? _FieldMap(
                  field: parcel,
                  nearby: nearby,
                  caption: [
                    ?parcel.address,
                    l10n.parcelNumber(parcel.id),
                  ].join('\n'),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.map_outlined, size: 48),
                ),
        ),
        if (_loading) const LinearProgressIndicator(),
        const SizedBox(height: 16),

        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 20),
          ),
          icon: const Icon(Icons.autorenew, size: 28),
          label: Text(l10n.rotationStart),
          onPressed: parcel == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RotationWizardPage(parcel: parcel),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          parcel == null ? l10n.rotationStartNeedPlot : l10n.rotationStartHint,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 24),

        // Parcels near the user's location (from the map)
        if (nearby.isNotEmpty) ...[
          Text(l10n.nearbyParcelsSection, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          NearbyPlotList(
            parcels: nearby,
            selectedId: parcel?.id,
            onSelected: widget.store.select,
          ),
          const SizedBox(height: 24),
        ],

        // Plot input form (left as-is)
        // Text(l10n.plotDataSection, style: theme.textTheme.titleMedium),
        // const SizedBox(height: 8),
        // The address is typed in the search field at the top.
        // No "Save" button until the plot can be saved somewhere (it used
        // to clear the form without saving anything).
        PlotInput(address: parcel?.address ?? ''),
        const SizedBox(height: 24),

        // Info cards
        Text(l10n.infoSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.landscape_outlined,
                label: l10n.soil,
                value: '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(icon: Icons.grass, label: l10n.crop, value: '—'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.water_drop_outlined,
                label: l10n.moisture,
                value: '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                icon: Icons.thermostat_outlined,
                label: l10n.temperature,
                value: '—',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The same map as the "Map" screen, but view-only (no tap handler, so the
/// parcels cannot be chosen here), fitted around the field, with its address
/// on top.
class _FieldMap extends StatelessWidget {
  const _FieldMap({
    required this.field,
    required this.nearby,
    required this.caption,
  });

  final Parcel field;
  final List<Parcel> nearby;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: ParcelMap(myField: field, parcels: nearby, fitMyField: true),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(caption),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelMedium),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
