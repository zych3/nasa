import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/map_button.dart';
import '../components/nearby_plot_list.dart';
import '../components/parcel_map.dart';
import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../overlays/field_conditions_controller.dart';
import '../overlays/map_layers_repository.dart';
import '../repositories/selected_plot_store.dart';
import '../widgets/field_conditions_section.dart';
import 'rotation_wizard_page.dart';

/// "Moje pole" – plot data page. Shows the chosen (saved) parcel and lets the
/// user pick another one from the parcels nearby. Addresses are searched on
/// the "My area" map.
class PlotPage extends StatefulWidget {
  const PlotPage({
    super.key,
    required this.store,
    this.repository,
    this.onShowConditions,
  });

  final SelectedPlotStore store;

  /// NASA and parcel data; share the "Conditions" tab's one so both use the
  /// same cache (one request per place).
  final MapLayersRepository? repository;

  /// Opens the "Conditions" tab.
  final VoidCallback? onShowConditions;

  @override
  State<PlotPage> createState() => _PlotPageState();
}

class _PlotPageState extends State<PlotPage> {
  late final _conditions = FieldConditionsController(
    repository: widget.repository ?? MapLayersRepository(),
  );

  @override
  void initState() {
    super.initState();
    // Start loading at once (the data can take a while) and again whenever
    // another field is chosen.
    _conditions.show(widget.store.parcel);
    widget.store.addListener(_fieldChanged);
  }

  @override
  void didUpdateWidget(PlotPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_fieldChanged);
      widget.store.addListener(_fieldChanged);
      _fieldChanged();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_fieldChanged);
    _conditions.dispose();
    super.dispose();
  }

  void _fieldChanged() => _conditions.show(widget.store.parcel);

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

    // Centred column on wide (web) screens, so lines stay readable.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // Title: the field's address (or "My plot" when it has none) and
            // its parcel number. Room on the right for the language button
            // floating in the top corner. (Fields are found on the "My area"
            // map, which has the address search.)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: MapButton.reservedEnd - 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.navPlot.toUpperCase(),
                    style: type.body.sm.copyWith(
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    header: true,
                    child: Text(
                      parcel?.address ?? l10n.plotName,
                      style: type.display.xl2.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  if (parcel != null) ...[
                    const SizedBox(height: 10),
                    FBadge(
                      variant: FBadgeVariant.secondary,
                      child: Text(l10n.parcelNumber(parcel.id)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Map: the field once chosen, a quiet placeholder before that.
            FCard(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 240,
                child: parcel != null
                    ? ParcelMap(
                        myField: parcel,
                        parcels: nearby,
                        fitMyField: true,
                      )
                    : ColoredBox(
                        color: colors.muted,
                        child: Center(
                          child: Icon(
                            FLucideIcons.map,
                            size: 40,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            FButton(
              size: FButtonSizeVariant.lg,
              onPress: parcel == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RotationWizardPage(parcel: parcel),
                      ),
                    ),
              prefix: const Icon(FLucideIcons.refreshCcw),
              child: Flexible(
                child: Text(l10n.rotationStart, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              parcel == null
                  ? l10n.rotationStartNeedPlot
                  : l10n.rotationStartHint,
              style: type.body.md.copyWith(color: colors.mutedForeground),
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

            // What NASA data and the registers say about the field. Fills in
            // as the data arrives (progress bar until then).
            const SizedBox(height: 36),
            FieldConditionsSection(
              controller: _conditions,
              hasField: parcel != null,
              onShowOnMap: widget.onShowConditions,
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
      padding: const EdgeInsets.only(top: 36, bottom: 12),
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
