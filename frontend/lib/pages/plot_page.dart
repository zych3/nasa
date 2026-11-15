import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/address_search_field.dart';
import '../components/forui_page_theme.dart';
import '../components/input/plotInput/plot_input.dart';
import '../components/nearby_plot_list.dart';
import '../components/parcel_map.dart';
import '../l10n/app_localizations.dart';
import '../models/address_suggestion.dart';
import '../models/parcel.dart';
import '../repositories/parcel_repository.dart';
import '../repositories/selected_plot_store.dart';

/// "Moje pole" – plot data page. Shows the chosen (saved) parcel and lets the
/// user pick another one from the parcels nearby or by typing an address.
///
/// Styled with forui through [ForuiPageTheme] (light or dark like the phone).
class PlotPage extends StatelessWidget {
  const PlotPage({super.key, required this.store});

  final SelectedPlotStore store;

  @override
  Widget build(BuildContext context) {
    return ForuiPageTheme(
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.theme.colors.background,
          child: _PlotPageBody(store: store),
        ),
      ),
    );
  }
}

class _PlotPageBody extends StatefulWidget {
  const _PlotPageBody({required this.store});

  final SelectedPlotStore store;

  @override
  State<_PlotPageBody> createState() => _PlotPageBodyState();
}

class _PlotPageBodyState extends State<_PlotPageBody> {
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
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final Parcel? parcel = widget.store.parcel;
    final nearby = widget.store.nearby;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // Keeps lines readable on wide (web) screens.
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // Page title and the chosen address (or what to do first).
            Text(
              l10n.navPlot,
              style: type.display.xl2.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              parcel?.address ?? l10n.plotNoParcelYet,
              style: type.body.md.copyWith(color: colors.mutedForeground),
            ),
            const SizedBox(height: 24),

            AddressSearchField(
              onAddressChosen: _choosePoint,
              onSearch: _findParcel,
            ),
            const SizedBox(height: 24),

            // The parcel: map on top, address and number below.
            FCard(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 260,
                    child: parcel != null
                        ? ParcelMap(parcel: parcel, rounded: false)
                        : ColoredBox(
                            color: colors.muted,
                            child: Icon(
                              Icons.map_outlined,
                              size: 48,
                              color: colors.mutedForeground,
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 3,
                    child: _loading ? const LinearProgressIndicator() : null,
                  ),
                  if (parcel != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
                      // Badge under the address: long parcel numbers
                      // would not fit next to it on a phone.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parcel.address ?? l10n.plotName,
                            style: type.body.md.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FBadge(
                            variant: FBadgeVariant.secondary,
                            child: Text(l10n.parcelNumber(parcel.id)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Parcels near the user's location (from the map).
            if (nearby.isNotEmpty) ...[
              _SectionTitle(l10n.nearbyParcelsSection),
              NearbyPlotList(
                parcels: nearby,
                selectedId: parcel?.id,
                onSelected: widget.store.select,
              ),
            ],

            // Crops grown on the plot. The address is typed at the top.
            _SectionTitle(l10n.plotDataSection),
            FCard(
              child: PlotInput(
                onSubmitPlot: (_) {},
                address: parcel?.address ?? '',
              ),
            ),

            // Info tiles.
            _SectionTitle(l10n.infoSection),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _InfoTile(
                  icon: Icons.landscape_outlined,
                  label: l10n.soil,
                  value: '—',
                ),
                _InfoTile(icon: Icons.grass, label: l10n.crop, value: '—'),
                _InfoTile(
                  icon: Icons.water_drop_outlined,
                  label: l10n.moisture,
                  value: '—',
                ),
                _InfoTile(
                  icon: Icons.thermostat_outlined,
                  label: l10n.temperature,
                  value: '—',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.typography.display.lg.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: colors.foreground),
            ),
            const Spacer(),
            Text(
              label,
              style: type.body.md.copyWith(color: colors.mutedForeground),
            ),
            Text(
              value,
              style: type.display.xl.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
