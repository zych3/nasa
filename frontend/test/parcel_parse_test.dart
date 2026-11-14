import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/models/parcel.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('parseEwkt swaps lon/lat and keeps the closed ring', () {
    const ewkt =
        'SRID=4326;POLYGON((20.9822120321816 52.0623662323497,'
        '20.9818320731392 52.0622421405681,'
        '20.9821557935646 52.0618791663499,'
        '20.982531958785 52.062004065461,'
        '20.982415690929 52.0621301492357,'
        '20.9822120321816 52.0623662323497))';

    final ring = parseEwkt(ewkt);

    expect(ring, hasLength(6));
    expect(ring.first, const LatLng(52.0623662323497, 20.9822120321816));
    expect(ring.first, ring.last);
  });

  test('parseEwkt rejects non-polygon geometry', () {
    expect(() => parseEwkt('SRID=4326;POINT(20 52)'), throwsFormatException);
  });
}
