import 'rotation_report.dart';
import 'saved_plan.dart';

/// A rotation plan the user kept. The phone is where plans live; an account,
/// when there is one, only holds a copy ([serverId]) so they can be loaded on
/// another device.
class LocalPlan {
  const LocalPlan({
    required this.id,
    required this.createdAt,
    required this.goal,
    required this.plan,
    this.parcelId,
    this.lat,
    this.lon,
    this.answers,
    this.serverId,
  });

  /// Id on this device.
  final String id;

  /// Id of the copy in the account; null while there is none.
  final String? serverId;

  final DateTime createdAt;
  final String goal;
  final RotationPlan plan;
  final String? parcelId;
  final double? lat;
  final double? lon;

  /// The answers the plan was made from, as sent to the backend.
  final Map<String, dynamic>? answers;

  /// Same goal, place and crops in the same years: two copies of this are the
  /// same plan, whichever device saved them.
  String get fingerprint => fingerprintOf(goal, lat, lon, plan);

  static String fingerprintOf(
    String goal,
    double? lat,
    double? lon,
    RotationPlan plan,
  ) {
    final seasons = [
      for (final s in plan.seasons)
        '${s.year}:${s.crop.id}:${s.catchCrop?.id ?? ''}',
    ];
    return [
      goal,
      lat?.toStringAsFixed(4) ?? '',
      lon?.toStringAsFixed(4) ?? '',
      ...seasons,
    ].join('|');
  }

  LocalPlan withServerId(String? serverId) => LocalPlan(
    id: id,
    createdAt: createdAt,
    goal: goal,
    plan: plan,
    parcelId: parcelId,
    lat: lat,
    lon: lon,
    answers: answers,
    serverId: serverId,
  );

  SavedPlan toSavedPlan() => SavedPlan(
    id: id,
    createdAt: createdAt,
    goal: goal,
    plan: plan,
    parcelId: parcelId,
    lat: lat,
    lon: lon,
  );

  factory LocalPlan.fromSaved(SavedPlan saved, {required String id}) =>
      LocalPlan(
        id: id,
        serverId: saved.id,
        createdAt: saved.createdAt,
        goal: saved.goal,
        plan: saved.plan,
        parcelId: saved.parcelId,
        lat: saved.lat,
        lon: saved.lon,
      );

  factory LocalPlan.fromJson(Map<String, dynamic> json) => LocalPlan(
    id: json['id'] as String,
    serverId: json['serverId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    goal: json['goal'] as String,
    plan: RotationPlan.fromJson(json['plan'] as Map<String, dynamic>),
    parcelId: json['parcelId'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    answers: json['answers'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverId': ?serverId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'goal': goal,
    'plan': plan.raw,
    'parcelId': ?parcelId,
    'lat': ?lat,
    'lon': ?lon,
    'answers': ?answers,
  };
}
