class RotationReport {
  const RotationReport({
    required this.status,
    required this.mainGoal,
    required this.goals,
    required this.warnings,
    required this.inputs,
  });

  final String status;
  final String mainGoal;
  final List<GoalPlans> goals;
  final List<ReportWarning> warnings;
  final List<ReportInput> inputs;

  bool get hasPlan => status == 'ok' && goals.any((g) => g.goal == mainGoal);

  GoalPlans? plansFor(String goal) {
    for (final g in goals) {
      if (g.goal == goal) return g;
    }
    for (final g in goals) {
      if (g.goal == mainGoal) return g;
    }
    return goals.isEmpty ? null : goals.first;
  }

  factory RotationReport.fromJson(Map<String, dynamic> json) => RotationReport(
    status: json['status'] as String? ?? 'no_plan',
    mainGoal: json['mainGoal'] as String? ?? 'balanced',
    goals: _list(json['recommendations'], GoalPlans.fromJson),
    warnings: _list(json['warnings'], ReportWarning.fromJson),
    inputs: _list(json['inputs'], ReportInput.fromJson),
  );
}

List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) parse) => [
  for (final item in json as List? ?? const [])
    parse(item as Map<String, dynamic>),
];

class GoalPlans {
  const GoalPlans({
    required this.goal,
    required this.best,
    required this.alternatives,
  });

  final String goal;
  final RotationPlan best;
  final List<RotationPlan> alternatives;

  factory GoalPlans.fromJson(Map<String, dynamic> json) => GoalPlans(
    goal: json['goal'] as String,
    best: RotationPlan.fromJson(json['best'] as Map<String, dynamic>),
    alternatives: _list(json['alternatives'], RotationPlan.fromJson),
  );
}

class RotationPlan {
  const RotationPlan({
    required this.transition,
    required this.cycle,
    required this.cycleYears,
    required this.scores,
    required this.reasons,
    required this.isFeasible,
    this.raw = const {},
  });

  /// The plan as the backend sent it, kept so it can be saved to the profile
  /// exactly as it was shown.
  final Map<String, dynamic> raw;

  final List<PlanSeason> transition;
  final List<PlanSeason> cycle;
  final int cycleYears;
  final List<PlanScore> scores;
  final List<PlanReason> reasons;
  final bool isFeasible;

  List<PlanSeason> get seasons => [...transition, ...cycle];

  Rating? score(String key) {
    for (final s in scores) {
      if (s.key == key) return s.rating;
    }
    return null;
  }

  factory RotationPlan.fromJson(Map<String, dynamic> json) => RotationPlan(
    transition: _list(json['transition'], PlanSeason.fromJson),
    cycle: _list(json['cycle'], PlanSeason.fromJson),
    cycleYears: json['cycleYears'] as int? ?? 0,
    scores: _list(json['scores'], PlanScore.fromJson),
    reasons: _list(json['reasons'], PlanReason.fromJson),
    isFeasible: json['isFeasible'] as bool? ?? true,
    raw: json,
  );
}

class PlanSeason {
  const PlanSeason({
    required this.year,
    required this.crop,
    required this.harvest,
    this.catchCrop,
  });

  final int year;
  final PlanCrop crop;
  final PlanCrop? catchCrop;
  final Rating harvest;

  factory PlanSeason.fromJson(Map<String, dynamic> json) => PlanSeason(
    year: json['harvestYear'] as int,
    crop: PlanCrop.fromJson(json['crop'] as Map<String, dynamic>),
    catchCrop: json['catchCrop'] == null
        ? null
        : PlanCrop.fromJson(json['catchCrop'] as Map<String, dynamic>),
    harvest: Rating.fromJson(json['harvest'] as Map<String, dynamic>),
  );
}

class DayRange {
  const DayRange({required this.from, required this.to});

  final int from;
  final int to;

  static DayRange? tryParse(Object? json) => json is Map<String, dynamic>
      ? DayRange(from: json['from'] as int, to: json['to'] as int)
      : null;
}

class PlanCrop {
  const PlanCrop({
    required this.id,
    required this.names,
    this.catalogId,
    this.sow,
    this.harvest,
    this.sownPreviousYear = false,
  });

  final String id;
  final Map<String, String> names;

  final String? catalogId;

  final DayRange? sow;
  final DayRange? harvest;

  final bool sownPreviousYear;

  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? id;

  factory PlanCrop.fromJson(Map<String, dynamic> json) => PlanCrop(
    id: json['id'] as String,
    names: {
      for (final e
          in (json['name'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: e.value as String,
    },
    catalogId: json['catalogId'] as String?,
    sow: DayRange.tryParse(json['sow']),
    harvest: DayRange.tryParse(json['harvest']),
    sownPreviousYear: json['sownPreviousYear'] as bool? ?? false,
  );
}

class Rating {
  const Rating({required this.value, required this.level});

  final double value;

  final String level;

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
    value: (json['value'] as num).toDouble(),
    level: json['level'] as String? ?? 'ok',
  );
}

class PlanScore {
  const PlanScore({required this.key, required this.rating});

  final String key;
  final Rating rating;

  factory PlanScore.fromJson(Map<String, dynamic> json) => PlanScore(
    key: json['key'] as String,
    rating: Rating.fromJson(json['rating'] as Map<String, dynamic>),
  );
}

class PlanReason {
  const PlanReason({
    required this.code,
    required this.delta,
    this.cropId,
    this.variable,
  });

  final String code;
  final String? cropId;
  final String? variable;
  final double delta;

  factory PlanReason.fromJson(Map<String, dynamic> json) => PlanReason(
    code: json['code'] as String,
    cropId: json['cropId'] as String?,
    variable: json['var'] as String?,
    delta: (json['delta'] as num).toDouble(),
  );
}

class ReportWarning {
  const ReportWarning({required this.code, this.subject});

  final String code;
  final String? subject;

  factory ReportWarning.fromJson(Map<String, dynamic> json) => ReportWarning(
    code: json['code'] as String,
    subject: json['subject'] as String?,
  );
}

class ReportInput {
  const ReportInput({required this.key, required this.origin});

  final String key;

  final String origin;

  factory ReportInput.fromJson(Map<String, dynamic> json) =>
      ReportInput(key: json['key'] as String, origin: json['origin'] as String);
}

class RotationAnswers {
  const RotationAnswers({
    required this.pastCrops,
    this.goal,
    this.excludedCrops = const [],
    this.hasLivestock,
    this.hasIrrigation,
    this.soilPhKCl,
  });

  final List<String> pastCrops;

  final String? goal;
  final List<String> excludedCrops;
  final bool? hasLivestock;
  final bool? hasIrrigation;
  final double? soilPhKCl;

  Map<String, dynamic> toJson({
    required String? parcelId,
    required double lat,
    required double lon,
  }) => {
    'parcelId': ?parcelId,
    'lat': lat,
    'lon': lon,
    'pastCrops': pastCrops,
    'goal': ?goal,
    if (excludedCrops.isNotEmpty) 'excludedCrops': excludedCrops,
    'hasLivestock': ?hasLivestock,
    'hasIrrigation': ?hasIrrigation,
    'soilPhKCl': ?soilPhKCl,
  };
}
