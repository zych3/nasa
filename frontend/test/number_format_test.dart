import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/crop_summary_card.dart';
import 'package:hopito_field_shift/components/nearby_plot_list.dart';

void main() {
  test('distance uses the decimal separator of the language', () {
    expect(formatDistance(12.4, 'pl'), '12 m');
    expect(formatDistance(1420, 'pl'), '1,4 km');
    expect(formatDistance(1420, 'en'), '1.4 km');
    expect(formatDistance(12000, 'en'), '12.0 km');
  });

  test('price change: sign, one decimal, separator of the language', () {
    expect(formatPercentChange(3.46, 'pl'), '+3,5');
    expect(formatPercentChange(3.46, 'en'), '+3.5');
    expect(formatPercentChange(-1.24, 'pl'), '-1,2');
    expect(formatPercentChange(0, 'en'), '0.0');
    // Rounds to zero: no "+0.0".
    expect(formatPercentChange(0.04, 'en'), '0.0');
  });
}
