import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../components/map_button.dart';
import '../components/my_plot_list.dart';
import '../components/parcel_map.dart';
import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../overlays/field_conditions_controller.dart';
import '../overlays/map_layers_repository.dart';
import '../repositories/auth_store.dart';
import '../repositories/my_parcels_store.dart';
import '../repositories/selected_plot_store.dart';
import '../widgets/field_conditions_section.dart';
import 'rotation_wizard_page.dart';

/// "Moje pole" – plot data page: the chosen (saved) parcel and what recent
/// NASA satellite data and the registers say about it. Fields are chosen on
/// the "My area" map (also by address).
class PlotPage extends StatefulWidget {
  const PlotPage({
    super.key,
    required this.store,
    required this.authStore,
    this.repository,
    this.onShowConditions,
    this.parcels,
  });

  final SelectedPlotStore store;

  /// Saving a rotation plan needs an account; passed on to the planner.
  final AuthStore authStore;

  /// NASA and parcel data; share the "Conditions" tab's one so both use the
  /// same cache (one request per place).
  final MapLayersRepository? repository;

  /// Opens the "Conditions" tab.
  final VoidCallback? onShowConditions;

  /// "My parcels" (the app's own list by default).
  final MyParcelsStore? parcels;

  @override
  State<PlotPage> createState() => _PlotPageState();
}

class _PlotPageState extends State<PlotPage> {
  late final MyParcelsStore _mine = widget.parcels ?? MyParcelsStore.shared;
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

  Future<void> _remove(Parcel parcel) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _mine.remove(parcel.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.myParcelRemoved)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, _mine, widget.authStore]),
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
    final mine = _mine.parcels;

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
                        builder: (_) => RotationWizardPage(
                          parcel: parcel,
                          authStore: widget.authStore,
                        ),
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

            // The user's own parcels: added on the map ("Is this your
            // parcel?"), removed by swiping to the right.
            const SizedBox(height: 32),
            Semantics(
              header: true,
              child: Text(
                l10n.myParcelsTitle,
                style: type.display.xl.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (mine.isEmpty)
              Text(
                l10n.myParcelsEmpty,
                style: type.body.md.copyWith(color: colors.mutedForeground),
              )
            else ...[
              Text(
                l10n.myParcelsSwipeHint,
                style: type.body.md.copyWith(color: colors.mutedForeground),
              ),
              const SizedBox(height: 8),
              MyPlotList(
                parcels: mine,
                selectedId: parcel?.id,
                onSelected: widget.store.select,
                onRemoved: _remove,
              ),
              if (widget.authStore.status == AuthStatus.signedIn &&
                  _mine.syncedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.myParcelsSynced(
                      DateFormat.yMd(Localizations.localeOf(context).toString())
                          .add_Hm()
                          .format(_mine.syncedAt!.toLocal()),
                    ),
                    style: type.body.sm.copyWith(color: colors.mutedForeground),
                  ),
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
