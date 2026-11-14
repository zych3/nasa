import 'package:flutter_map/flutter_map.dart';
import 'package:material_ui/material_ui.dart';

import '../models/parcel.dart';

/// Map with the parcel outline highlighted; the camera fits the parcel.
class ParcelMap extends StatefulWidget {
  const ParcelMap({super.key, required this.parcel, this.caption});

  final Parcel parcel;

  /// Label shown over the map (e.g. address and parcel number).
  final String? caption;

  @override
  State<ParcelMap> createState() => _ParcelMapState();
}

class _ParcelMapState extends State<ParcelMap> {
  final _controller = MapController();

  CameraFit _fit() => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(widget.parcel.ring),
    padding: const EdgeInsets.all(40),
    maxZoom: 19,
  );

  @override
  void didUpdateWidget(ParcelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parcel.id != widget.parcel.id) {
      _controller.fitCamera(_fit());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    final caption = widget.caption;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(child: _buildMap(color)),
          if (caption != null)
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

  Widget _buildMap(Color color) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(initialCameraFit: _fit()),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'hopito_field_shift',
        ),
        PolygonLayer(
          polygons: [
            Polygon(
              points: widget.parcel.ring,
              color: color.withValues(alpha: 0.3),
              borderColor: color,
              borderStrokeWidth: 3,
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
