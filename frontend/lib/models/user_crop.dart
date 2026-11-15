import 'package:latlong2/latlong.dart';

/// One crop the signed-in user grows at one place (`/api/my-crops`).
/// Saved so that later the app can check whether it is at risk; [isActive]
/// says whether the user wants it checked.
class UserCrop {
  const UserCrop({
    required this.id,
    required this.cropId,
    required this.point,
    required this.isActive,
    required this.updatedAt,
    this.parcelId,
    this.label,
  });

  final String id;

  /// Crop id from the catalogue (`GET /api/crops`), e.g. "wheat".
  final String cropId;
  final LatLng point;
  final String? parcelId;

  /// The user's words for the place, e.g. the address.
  final String? label;
  final bool isActive;
  final DateTime updatedAt;

  factory UserCrop.fromJson(Map<String, dynamic> json) => UserCrop(
    id: json['id'] as String,
    cropId: json['cropId'] as String,
    point: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    parcelId: json['parcelId'] as String?,
    label: json['label'] as String?,
    isActive: json['isActive'] as bool,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

/// Why a "my crops" call failed; the screen picks the words.
enum UserCropError {
  /// The session ended (401): sign in again.
  signedOut,

  /// The backend rejected the data (unknown crop, too many entries...).
  rejected,
  serverUnavailable,
  noConnection,
}

class UserCropException implements Exception {
  const UserCropException(this.error);

  final UserCropError error;

  @override
  String toString() => 'UserCropException($error)';
}
