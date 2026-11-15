import 'package:forui/forui.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/farm_indicators.dart';

/// "What it means for your field": erosion, plant stress, ground warmth,
/// moisture and field access, fungal weather. Each in words, with a level
/// shown by icon and word (never colour alone), the reasons with their
/// numbers and the data it comes from. All estimates.
class FarmIndicatorsCard extends StatelessWidget {
  const FarmIndicatorsCard({super.key, required this.indicators});

  final FarmIndicators indicators;

  /// Indicators at a high level, as sentences for the "Watch out" box.
  static List<String> warnings(AppLocalizations l10n, FarmIndicators i) => [
    if (i.erosion?.level == RiskLevel.high)
      l10n.indicatorWarning(
        l10n.indErosionTitle,
        _erosionMain(l10n, RiskLevel.high),
      ),
    if (i.plantStress?.level == RiskLevel.high)
      l10n.indicatorWarning(
        l10n.indStressTitle,
        _stressMain(l10n, RiskLevel.high),
      ),
    if (i.moistureState == MoistureState.tooWet) l10n.indMoistureTooWet,
    if (i.groundState == GroundState.frozen) l10n.indGroundFrozen,
    if (i.fungal?.level == RiskLevel.high)
      l10n.indicatorWarning(
        l10n.indFungalTitle,
        _fungalMain(l10n, RiskLevel.high),
      ),
  ];

  /// Every row as sentences, for reading aloud.
  static List<String> sentences(AppLocalizations l10n, FarmIndicators i) => [
    for (final row in _rows(l10n, i)) ...[
      l10n.indicatorWarning(row.title, row.main),
      for (final r in row.indicator.reasons) _reason(l10n, r),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final rows = _rows(l10n, indicators);
    if (rows.isEmpty) return const SizedBox.shrink();

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.indTitle,
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.indSubtitle,
              style: theme.typography.body.sm.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const FDivider(),
              _IndicatorRow(row: row),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row: what is shown and how serious it is.
typedef _RowData = ({
  IconData icon,
  String title,
  String main,
  RiskLevel? level,

  /// The level is a risk (low / moderate / high); otherwise it is shown as
  /// "fine" / "watch out".
  bool isRisk,
  FarmIndicator indicator,
});

List<_RowData> _rows(AppLocalizations l10n, FarmIndicators i) => [
  if (i.moisture case final m?)
    (
      icon: FLucideIcons.droplets,
      title: l10n.indMoistureTitle,
      main: switch (i.moistureState) {
        MoistureState.tooWet => l10n.indMoistureTooWet,
        MoistureState.dry => l10n.indMoistureDry,
        MoistureState.ok => l10n.indMoistureOk,
        null => l10n.indMoistureUnknown,
      },
      level: switch (i.moistureState) {
        MoistureState.tooWet || MoistureState.dry => RiskLevel.moderate,
        MoistureState.ok => RiskLevel.low,
        null => null,
      },
      isRisk: false,
      indicator: m,
    ),
  if (i.plantStress case final s?)
    (
      icon: FLucideIcons.leaf,
      title: l10n.indStressTitle,
      main: _stressMain(l10n, s.level),
      level: s.level,
      isRisk: true,
      indicator: s,
    ),
  if (i.ground case final g?)
    (
      icon: FLucideIcons.thermometer,
      title: l10n.indGroundTitle,
      main: switch (i.groundState) {
        GroundState.frozen => l10n.indGroundFrozen,
        GroundState.cold => l10n.indGroundCold,
        GroundState.cool => l10n.indGroundCool,
        GroundState.warm => l10n.indGroundWarm,
        null => l10n.indGroundUnknown,
      },
      level: switch (i.groundState) {
        GroundState.frozen => RiskLevel.high,
        GroundState.cold => RiskLevel.moderate,
        GroundState.cool || GroundState.warm => RiskLevel.low,
        null => null,
      },
      isRisk: false,
      indicator: g,
    ),
  if (i.erosion case final e?)
    (
      icon: FLucideIcons.waves,
      title: l10n.indErosionTitle,
      main: _erosionMain(l10n, e.level),
      level: e.level,
      isRisk: true,
      indicator: e,
    ),
  if (i.fungal case final f?)
    (
      icon: FLucideIcons.sprout,
      title: l10n.indFungalTitle,
      main: _fungalMain(l10n, f.level),
      level: f.level,
      isRisk: true,
      indicator: f,
    ),
];

String _erosionMain(AppLocalizations l10n, RiskLevel? level) => switch (level) {
  RiskLevel.high => l10n.indErosionHigh,
  RiskLevel.moderate => l10n.indErosionModerate,
  _ => l10n.indErosionLow,
};

String _stressMain(AppLocalizations l10n, RiskLevel? level) => switch (level) {
  RiskLevel.high => l10n.indStressHigh,
  RiskLevel.moderate => l10n.indStressModerate,
  _ => l10n.indStressLow,
};

String _fungalMain(AppLocalizations l10n, RiskLevel? level) => switch (level) {
  RiskLevel.high => l10n.indFungalHigh,
  RiskLevel.moderate => l10n.indFungalModerate,
  _ => l10n.indFungalLow,
};

String _reason(AppLocalizations l10n, Reason r) {
  String n(double? v, int d) => v == null
      ? '–'
      : NumberFormat.decimalPatternDigits(
          locale: l10n.localeName,
          decimalDigits: d,
        ).format(v);
  int count(double? v) => (v ?? 0).round();
  return switch (r.kind) {
    ReasonKind.heavyRainDays => l10n.indRHeavyRainDays(count(r.a)),
    ReasonKind.maxDailyRain => l10n.indRMaxDailyRain(n(r.a, 1)),
    ReasonKind.wetTopsoil => l10n.indRWetTopsoil(n(r.a, 2)),
    ReasonKind.slope => l10n.indRSlope(n(r.a, 1)),
    ReasonKind.lightSoil => l10n.indRLightSoil(n(r.a, 0)),
    ReasonKind.sparseCover => l10n.indRSparseCover(n(r.a, 2)),
    ReasonKind.noErosionDrivers => l10n.indRNoErosionDrivers,
    ReasonKind.dryRoots =>
      r.b == null
          ? l10n.indRRoots(n(r.a, 2))
          : l10n.indRDryRoots(n(r.a, 2), n(r.b, 2)),
    ReasonKind.wetRoots =>
      r.b == null
          ? l10n.indRRoots(n(r.a, 2))
          : l10n.indRWetRoots(n(r.a, 2), n(r.b, 2)),
    ReasonKind.rootsAsUsual =>
      r.b == null
          ? l10n.indRRoots(n(r.a, 2))
          : l10n.indRRootsAsUsual(n(r.a, 2), n(r.b, 2)),
    ReasonKind.hotDays => l10n.indRHotDays(n(r.a, 0)),
    ReasonKind.lessGreen => l10n.indRLessGreen(n(r.a, 2), n(r.b, 2)),
    ReasonKind.lessWaterUse => l10n.indRLessWaterUse(n(r.a, 1), n(r.b, 1)),
    ReasonKind.dormant => l10n.indRDormant(n(r.a, 1)),
    ReasonKind.noStress => l10n.indRNoStress,
    ReasonKind.soilTemp => l10n.indRSoilTemp(n(r.a, 1)),
    ReasonKind.warming => l10n.indRWarming(n(r.a, 1), count(r.b)),
    ReasonKind.cooling => l10n.indRCooling(n(r.a, 1), count(r.b)),
    ReasonKind.steady => l10n.indRSteady(count(r.a)),
    ReasonKind.frostNights => l10n.indRFrostNights(n(r.a, 0)),
    ReasonKind.veryWetTopsoil => l10n.indRVeryWetTopsoil(n(r.a, 2)),
    ReasonKind.rainWeek => l10n.indRRainWeek(n(r.a, 1)),
    ReasonKind.dryDays => l10n.indRDryDays(count(r.a)),
    ReasonKind.rainyDays => l10n.indRRainyDays(count(r.a)),
    ReasonKind.mildGround => l10n.indRMildGround(n(r.a, 0)),
  };
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.row});

  final _RowData row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final (
      IconData? levelIcon,
      Color levelColor,
      String? levelWord,
    ) = switch (row.level) {
      RiskLevel.high => (
        FLucideIcons.triangleAlert,
        colors.error,
        row.isRisk ? l10n.indLevelHigh : l10n.indAttention,
      ),
      RiskLevel.moderate => (
        FLucideIcons.circleAlert,
        const Color(0xFFB26A00),
        row.isRisk ? l10n.indLevelModerate : l10n.indAttention,
      ),
      RiskLevel.low => (
        FLucideIcons.circleCheck,
        colors.primary,
        row.isRisk ? l10n.indLevelLow : l10n.indOk,
      ),
      null => (null, colors.foreground, null),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(row.icon, size: 22, color: colors.foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: type.body.sm.copyWith(color: colors.mutedForeground),
                ),
                const SizedBox(height: 4),
                if (levelIcon != null && levelWord != null) ...[
                  Semantics(
                    label: levelWord,
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        Icon(levelIcon, size: 18, color: levelColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            levelWord,
                            style: type.body.sm.copyWith(
                              color: levelColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  row.main,
                  style: type.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                for (final r in row.indicator.reasons) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 9, right: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.mutedForeground,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _reason(l10n, r),
                          style: type.body.sm.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (row.indicator.sources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.indSources(row.indicator.sources.join(', ')),
                    style: type.body.xs.copyWith(color: colors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
