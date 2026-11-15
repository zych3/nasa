/// Frost outlook for the next days at a point (`/api/weather/frost-risk`).
class FrostRisk {
  const FrostRisk({required this.risk, this.date, this.minTemperatureC});

  /// "none", "light" or "frost".
  final String risk;
  final DateTime? date;
  final double? minTemperatureC;

  bool get isFrost => risk == 'frost';
  bool get isLight => risk == 'light';
  bool get atRisk => isFrost || isLight;

  factory FrostRisk.fromJson(Map<String, dynamic> json) => FrostRisk(
    risk: json['risk'] as String? ?? 'none',
    date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
    minTemperatureC: (json['minTemperatureC'] as num?)?.toDouble(),
  );
}
