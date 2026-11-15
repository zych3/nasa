import 'rotation_report.dart';

/// A plan the user kept in their profile (`GET /api/me/plans`).
class SavedPlan {
  const SavedPlan({
    required this.id,
    required this.createdAt,
    required this.goal,
    required this.plan,
    this.parcelId,
    this.lat,
    this.lon,
  });

  final String id;
  final DateTime createdAt;

  /// "balanced", "soil_health" or "safe_harvest".
  final String goal;

  final RotationPlan plan;
  final String? parcelId;
  final double? lat;
  final double? lon;

  factory SavedPlan.fromJson(Map<String, dynamic> json) => SavedPlan(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    goal: json['goal'] as String,
    plan: RotationPlan.fromJson(json['plan'] as Map<String, dynamic>),
    parcelId: json['parcelId'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
  );
}
