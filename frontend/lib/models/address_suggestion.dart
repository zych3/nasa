import 'package:latlong2/latlong.dart';

/// What an address hint points at.
enum AddressSuggestionKind { place, street, address }

/// One search-as-you-type hint from `GET /api/parcels/suggest`.
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

  /// Administrative areas, most local first (commune, county, region).
  final List<String> area;

  /// The text to put in the search field when this hint is picked:
  /// "Wieliczka", "Wieliczka, Krakowska", "Wieliczka, Krakowska 1",
  /// or "Zakrzów 12" for villages without streets.
  String get text {
    final place = city ?? '';
    final rest = [?street, ?number].join(' ');
    if (rest.isEmpty) return place;
    if (street == null) return '$place $rest';
    return '$place, $rest';
  }

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      AddressSuggestion(
        kind: _kind(json['kind']),
        point: LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
        city: json['city'] as String?,
        street: json['street'] as String?,
        number: json['number'] as String?,
        postalCode: json['postalCode'] as String?,
        area: [for (final a in (json['area'] as List<dynamic>? ?? [])) '$a'],
      );

  static AddressSuggestionKind _kind(Object? value) =>
      switch ('$value'.toLowerCase()) {
        'street' => AddressSuggestionKind.street,
        'address' => AddressSuggestionKind.address,
        _ => AddressSuggestionKind.place,
      };
}
