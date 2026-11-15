import 'package:latlong2/latlong.dart';

/// Kind of address hint (backend sends a code).
enum AddressSuggestionKind { place, street, address }

/// One hint shown while the user types an address (`GET /api/parcels/suggest`).
class AddressSuggestion {
  const AddressSuggestion({
    required this.kind,
    required this.point,
    this.city,
    this.street,
    this.number,
    this.postalCode,
    this.area = const [],
  });

  final AddressSuggestionKind kind;
  final LatLng point;
  final String? city;
  final String? street;
  final String? number;
  final String? postalCode;

  /// Wider area, most local first (commune, county, region).
  final List<String> area;

  /// Main line, e.g. "Krakowska 1", "Zakrzów 12" (village without streets),
  /// "Wieliczka".
  String get title => switch (kind) {
    AddressSuggestionKind.place => city ?? '',
    _ => [street ?? city, number].nonNulls.join(' '),
  };

  /// Second line: postal code, town (when not in the title) and wider area.
  String get details => [
    [postalCode, if (street != null) city].nonNulls.join(' '),
    ...area.where((a) => a != city),
  ].where((s) => s.isNotEmpty).join(', ');

  /// Text put in the address field when this hint is chosen. Uses the format
  /// the backend understands: "Town, Street 1" or "Village 12".
  String get fillText => switch (kind) {
    AddressSuggestionKind.place => '${city ?? ''}, ',
    AddressSuggestionKind.street => '${city ?? ''}, ${street ?? ''} ',
    AddressSuggestionKind.address =>
      street != null ? '${city ?? ''}, $street ${number ?? ''}'.trim() : title,
  };

  /// Unknown kinds are dropped by [tryFromJson], never shown raw.
  static AddressSuggestion? tryFromJson(Map<String, dynamic> json) {
    final kind = switch (json['kind']) {
      'place' => AddressSuggestionKind.place,
      'street' => AddressSuggestionKind.street,
      'address' => AddressSuggestionKind.address,
      _ => null,
    };
    if (kind == null) return null;
    return AddressSuggestion(
      kind: kind,
      point: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      city: json['city'] as String?,
      street: json['street'] as String?,
      number: json['number'] as String?,
      postalCode: json['postalCode'] as String?,
      area: [
        for (final a in (json['area'] as List<dynamic>? ?? const [])) '$a',
      ],
    );
  }
}
