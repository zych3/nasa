import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/models/overlay_layer.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const distance = Distance();

  test('top and bounding box are one radius away from the centre', () {
    const area = OverlayArea(center: LatLng(52.2, 21.48), radiusMeters: 1000);

    expect(distance(area.center, area.top), closeTo(1000, 5));
    final [sw, ne] = area.boundingPoints;
    expect(
      distance(area.center, LatLng(area.center.latitude, ne.longitude)),
      closeTo(1000, 5),
    );
    expect(
      distance(area.center, LatLng(sw.latitude, area.center.longitude)),
      closeTo(1000, 5),
    );
  });

  test('stays within valid coordinates near the poles and the date line', () {
    const area = OverlayArea(
      center: LatLng(89.99, 179.99),
      radiusMeters: 50000,
    );

    expect(area.top.latitude, 90);
    expect(area.boundingPoints.last.latitude, 90);
    expect(area.boundingPoints.last.longitude, 180);
  });

  test('equal areas are equal (the map refits only on a real change)', () {
    expect(
      const OverlayArea(center: LatLng(52.2, 21.48), radiusMeters: 1000),
      const OverlayArea(center: LatLng(52.2, 21.48), radiusMeters: 1000),
    );
    expect(
      const OverlayArea(center: LatLng(52.2, 21.48), radiusMeters: 1000),
      isNot(
        const OverlayArea(center: LatLng(52.2, 21.48), radiusMeters: 25000),
      ),
    );
  });
}
