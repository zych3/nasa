import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../overlays/map_layers_repository.dart';
import '../overlays/overlay_controller.dart';
import '../repositories/selected_plot_store.dart';
import '../widgets/overlay_map.dart';
import '../widgets/overlay_panel.dart';

/// "Conditions" tab: map overlays (soil, ...) for the user's field, with a
/// heat map of the area around it for the NASA overlays.
///
/// The map is centred on the chosen field; without one it shows an example
/// place and offers to choose the field. Data is loaded only once the tab is
/// [active] (the tabs live in an `IndexedStack`, so they are all built at
/// start) and again when the user chooses another field.
///
/// Phone: map on top, panel below. Wide screen: map left, panel right.
class OverlaysScreen extends StatefulWidget {
  const OverlaysScreen({
    super.key,
    required this.store,
    this.active = true,
    this.repository,
    this.onChooseField,
  });

  /// Example place without a chosen field (the place of the saved demo data).
  static const examplePlace = LatLng(52.20, 21.48);

  /// From this width the panel goes next to the map.
  static const wideLayoutWidth = 720.0;

  final SelectedPlotStore store;

  /// The tab is visible; data is only loaded while it is.
  final bool active;

  /// Injectable for tests.
  final MapLayersRepository? repository;

  /// Opens the screen where the field is chosen.
  final VoidCallback? onChooseField;

  @override
  State<OverlaysScreen> createState() => _OverlaysScreenState();
}

class _OverlaysScreenState extends State<OverlaysScreen> {
  late final OverlayController _controller = OverlayController(
    repository: widget.repository ?? MapLayersRepository(),
  );

  LatLng get _place =>
      widget.store.parcel?.center ?? OverlaysScreen.examplePlace;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_showPlace);
    _showPlace();
  }

  @override
  void didUpdateWidget(OverlaysScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_showPlace);
      widget.store.addListener(_showPlace);
    }
    _showPlace();
  }

  @override
  void dispose() {
    widget.store.removeListener(_showPlace);
    _controller.dispose();
    super.dispose();
  }

  /// Cheap when nothing changed: the controller ignores the current place.
  void _showPlace() {
    if (widget.active) _controller.showPlace(_place);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, widget.store]),
      builder: (context, _) {
        final parcel = widget.store.parcel;
        final map = OverlayMap(
          center: _place,
          layer: _controller.layer,
          field: parcel,
          heatmap: _controller.heatmap,
          heatmapLoading:
              _controller.isHeatmapLoading && _controller.layer != null,
        );
        OverlayPanel panel({required bool wide}) => OverlayPanel(
          controller: _controller,
          showNoFieldNotice: parcel == null,
          onChooseField: widget.onChooseField,
          showTitle: wide,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= OverlaysScreen.wideLayoutWidth) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: map),
                  SizedBox(width: 420, child: panel(wide: true)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 4, child: map),
                Expanded(flex: 5, child: panel(wide: false)),
              ],
            );
          },
        );
      },
    );
  }
}
