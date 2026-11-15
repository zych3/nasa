import 'package:forui/forui.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/parcel_facts.dart';
import '../overlays/field_conditions_controller.dart';
import 'overlay_level_bars.dart';
import 'overlay_panel.dart' show overlayErrorText;
import 'read_aloud_button.dart';

/// "My field" summary: what NASA data says about the field's area (soil
/// moisture, rain, heat, frost, plant stress, erosion) and what the registers
/// and soil models say about the parcel. Shows a progress bar while the data
/// loads (the first time up to ~20 s) and fills in each part as it arrives.
class FieldConditionsSection extends StatelessWidget {
  const FieldConditionsSection({
    super.key,
    required this.controller,
    required this.hasField,
    this.onShowOnMap,
  });

  final FieldConditionsController controller;

  /// A field is chosen (otherwise only a hint is shown).
  final bool hasField;

  /// Opens the "Conditions" map, when there is one to open.
  final VoidCallback? onShowOnMap;

  /// Overlays whose top third means "watch out" (frost and pest warmth are
  /// left out: they are high every winter / autumn and would warn all season).
  static const _riskIds = {
    'plantStress',
    'erosionRisk',
    'heatStress',
    'fungalRisk',
  };

  static bool isWarning(FieldCondition c) {
    final index = c.layer.currentIndex;
    return _riskIds.contains(c.overlay.id) &&
        c.layer.ordered &&
        index != null &&
        index + 1 > c.layer.legend.length * 2 / 3;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;

    if (!hasField && !c.isDemo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(text: l10n.overlaysTitle),
          _Muted(l10n.fieldDataNoField),
        ],
      );
    }

    final warnings = c.conditions.where(isWarning).toList();
    final facts = c.facts;
    const gap = SizedBox(height: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          text: l10n.overlaysTitle,
          readAloud: () => _readAloudText(l10n),
        ),
        if (c.isDemo) ...[
          FAlert(
            icon: const Icon(FLucideIcons.info),
            title: Text(l10n.overlaysDemoNotice),
          ),
          gap,
        ],
        if (c.isLoading) ...[_LoadingCard(controller: c), gap],
        if (c.climateStatus == FieldDataStatus.failed) ...[
          _ErrorCard(
            message: overlayErrorText(l10n, c.climateError),
            onRetry: c.retry,
            onShowDemo: c.isDemo ? null : c.showDemo,
          ),
          gap,
        ],
        if (warnings.isNotEmpty) ...[
          FAlert(
            variant: FAlertVariant.destructive,
            icon: const Icon(FLucideIcons.triangleAlert),
            title: Text(l10n.fieldWarningsHeading),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in warnings)
                  Text(
                    l10n.fieldConditionSentence(
                      w.overlay.title(l10n),
                      w.layer.current!.label(l10n),
                    ),
                  ),
              ],
            ),
          ),
          gap,
        ],
        if (c.conditions.isNotEmpty) ...[
          _ConditionsCard(conditions: c.conditions, onShowOnMap: onShowOnMap),
          gap,
        ],
        if (facts != null)
          _FactsCard(facts: facts)
        else if (c.parcelStatus == FieldDataStatus.failed ||
            c.parcelStatus == FieldDataStatus.ready)
          _Muted(l10n.fieldFactsNone),
      ],
    );
  }

  String _readAloudText(AppLocalizations l10n) {
    final c = controller;
    return sentencesForReading([
      l10n.overlaysTitle,
      if (c.isDemo) l10n.overlaysDemoNotice,
      if (c.isLoading) l10n.fieldDataLoading,
      for (final condition in c.conditions)
        l10n.fieldConditionSentence(
          condition.overlay.title(l10n),
          condition.layer.current!.label(l10n),
        ),
      if (c.conditions.isNotEmpty) l10n.overlaysHeatmapCellSize,
      if (c.facts case final facts?) ..._factsSentences(l10n, facts),
    ]);
  }
}

List<String> _factsSentences(AppLocalizations l10n, ParcelFacts facts) => [
  for (final row in _factRows(l10n, facts))
    l10n.fieldFactSentence(row.label, row.value),
];

// ---------------------------------------------------------------- parts

class _Heading extends StatelessWidget {
  const _Heading({required this.text, this.readAloud});

  final String text;
  final String Function()? readAloud;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: theme.typography.display.lg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colors.foreground,
                ),
              ),
            ),
          ),
          if (readAloud case final read?) ...[
            const SizedBox(width: 8),
            ReadAloudButton(text: read),
          ],
        ],
      ),
    );
  }
}

/// Quiet sentence (hints, "nothing found").
class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Text(
      text,
      style: theme.typography.body.md.copyWith(
        color: theme.colors.mutedForeground,
      ),
    );
  }
}

/// Card body with the same padding everywhere.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FCard(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// Title of a card, with optional quiet lines under it.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text, {this.subtitle = const []});

  final String text;
  final List<String> subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: theme.typography.body.lg.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        for (final line in subtitle) ...[
          const SizedBox(height: 2),
          Text(
            line,
            style: theme.typography.body.sm.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.controller});

  final FieldConditionsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final progress = controller.progress;

    return _CardBody(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.fieldDataLoading,
            style: theme.typography.body.md.copyWith(
              color: theme.colors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Nothing back yet: moving bar; then the share of sources.
        if (progress == 0)
          FProgress(semanticsLabel: l10n.fieldDataLoading)
        else
          FDeterminateProgress(
            value: progress,
            semanticsLabel: l10n.fieldDataLoading,
          ),
        const SizedBox(height: 16),
        _Step(
          status: controller.climateStatus,
          text: l10n.fieldDataStepClimate,
        ),
        const SizedBox(height: 10),
        _Step(status: controller.parcelStatus, text: l10n.fieldDataStepParcel),
      ],
    );
  }
}

/// One source in the loading card: spinner, tick or cross, and its name.
class _Step extends StatelessWidget {
  const _Step({required this.status, required this.text});

  final FieldDataStatus status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final (Widget icon, String state) = switch (status) {
      FieldDataStatus.ready => (
        Icon(FLucideIcons.circleCheck, size: 20, color: colors.primary),
        l10n.fieldDataStepDone,
      ),
      FieldDataStatus.failed => (
        Icon(FLucideIcons.circleX, size: 20, color: colors.error),
        l10n.fieldDataStepFailed,
      ),
      _ => (const FCircularProgress(), l10n.fieldDataStepLoading),
    };
    return Semantics(
      label: l10n.fieldDataStepSemantics(text, state),
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(dimension: 24, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.typography.body.sm.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    this.onShowDemo,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onShowDemo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FAlert(
          variant: FAlertVariant.destructive,
          icon: const Icon(FLucideIcons.cloudOff),
          title: Text(message),
        ),
        const SizedBox(height: 12),
        FButton(
          onPress: onRetry,
          prefix: const Icon(FLucideIcons.refreshCw),
          child: Text(l10n.tryAgain),
        ),
        if (onShowDemo case final showDemo?) ...[
          const SizedBox(height: 8),
          FButton(
            variant: FButtonVariant.outline,
            onPress: showDemo,
            child: Flexible(
              child: Text(l10n.overlaysShowDemo, textAlign: TextAlign.center),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConditionsCard extends StatelessWidget {
  const _ConditionsCard({required this.conditions, this.onShowOnMap});

  final List<FieldCondition> conditions;
  final VoidCallback? onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // All NASA layers are for the same month and place.
    final month = conditions.first.layer.month;

    return _CardBody(
      children: [
        _CardTitle(
          l10n.fieldConditionsHeading,
          subtitle: [
            if (month != null)
              l10n.overlaysMonth(
                DateFormat.yMMMM(l10n.localeName).format(month),
              ),
            l10n.overlaysHeatmapCellSize,
          ],
        ),
        for (final (i, condition) in conditions.indexed) ...[
          if (i > 0) const FDivider(),
          _ConditionRow(condition: condition),
        ],
        if (onShowOnMap case final show?) ...[
          const SizedBox(height: 12),
          FButton(
            variant: FButtonVariant.outline,
            onPress: show,
            prefix: const Icon(FLucideIcons.layers),
            child: Flexible(
              child: Text(l10n.fieldShowOnMap, textAlign: TextAlign.center),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.condition});

  final FieldCondition condition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final layer = condition.layer;
    final current = layer.current!;
    final warning = FieldConditionsSection.isWarning(condition);
    final source = layer.source;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soft tile in the legend colour of the value (never the only
          // signal: the word and the bars say the same).
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                current.color.withValues(alpha: 0.22),
                colors.card,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              condition.overlay.icon,
              size: 22,
              color: colors.foreground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition.overlay.title(l10n),
                  style: type.body.sm.copyWith(color: colors.mutedForeground),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (warning) ...[
                      Icon(
                        FLucideIcons.triangleAlert,
                        size: 18,
                        color: colors.error,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        current.label(l10n),
                        style: type.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                    if (layer.ordered) ...[
                      const SizedBox(width: 8),
                      OverlayLevelBars(
                        level: layer.currentIndex! + 1,
                        count: layer.legend.length,
                        color: colors.foreground,
                        height: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (layer.isEstimate)
                      FBadge(
                        variant: FBadgeVariant.secondary,
                        child: Text(l10n.sourceEstimated),
                      ),
                    if (source != null)
                      Text(
                        l10n.overlaysSource(source),
                        style: type.body.xs.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts});

  final ParcelFacts facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final rows = _factRows(l10n, facts);

    return _CardBody(
      children: [
        _CardTitle(l10n.fieldFactsHeading),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const FDivider(),
          Padding(
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
                        row.label,
                        style: type.body.sm.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.value,
                        style: type.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                      if (row.note case final note?) ...[
                        const SizedBox(height: 6),
                        Text(
                          note,
                          style: type.body.xs.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

typedef _FactRow = ({IconData icon, String label, String value, String? note});

/// The facts as rows (label, value, source note), in the order a farmer
/// reads them: size, register class, soil, terrain, modelled soil.
List<_FactRow> _factRows(AppLocalizations l10n, ParcelFacts facts) {
  final locale = l10n.localeName;
  String number(double value, int decimals) =>
      NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimals,
      ).format(value);
  String? sourceNote(String? source, {bool estimate = false}) {
    final parts = [
      if (estimate) l10n.sourceEstimated,
      if (source != null) l10n.overlaysSource(source),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  final rows = <_FactRow>[];
  final registry = facts.landRegistry;

  if (facts.areaHa case final area?) {
    rows.add((
      icon: Icons.square_foot,
      label: l10n.fieldFactArea,
      value: l10n.fieldFactAreaValue(number(area, 2)),
      note: sourceNote(registry?.source),
    ));
  }
  if (registry != null && registry.classes.isNotEmpty) {
    rows.add((
      icon: Icons.workspace_premium_outlined,
      label: l10n.fieldFactQualityClass,
      value: registry.classes
          .map((c) => c.name == null ? c.code : '${c.code} – ${c.name}')
          .join('\n'),
      note: sourceNote(registry.source),
    ));
  }
  if (facts.soilMap case final map?) {
    final year = map.surveyYear;
    final note = [
      ?sourceNote(map.source),
      if (year != null) l10n.fieldFactSurveyed('$year'),
    ].join(' · ');
    if (map.complexName case final complex?) {
      rows.add((
        icon: Icons.grass,
        label: l10n.fieldFactSoilComplex,
        value: complex,
        note: note.isEmpty ? null : note,
      ));
    }
    if (map.soilTypeName case final type?) {
      rows.add((
        icon: Icons.layers_outlined,
        label: l10n.fieldFactSoilType,
        value: type,
        note: note.isEmpty ? null : note,
      ));
    }
  }
  if (facts.terrain case final terrain?) {
    final word = switch (terrain.level) {
      SlopeLevel.flat => l10n.fieldSlopeFlat,
      SlopeLevel.gentle => l10n.fieldSlopeGentle,
      SlopeLevel.moderate => l10n.fieldSlopeModerate,
      SlopeLevel.steep => l10n.fieldSlopeSteep,
    };
    rows.add((
      icon: Icons.terrain,
      label: l10n.fieldFactSlope,
      value: l10n.fieldFactSlopeValue(word, number(terrain.slopePct, 1)),
      note: [
        if (terrain.elevationM case final m?)
          l10n.fieldFactElevation(number(m, 0)),
        ?sourceNote(terrain.source),
      ].join(' · '),
    ));
  }
  if (facts.soil case final soil?) {
    final note = sourceNote(soil.source, estimate: true);
    if ((soil.ph, soil.phLevel) case (final ph?, final level?)) {
      final word = switch (level) {
        PhLevel.acidic => l10n.fieldPhAcidic,
        PhLevel.slightlyAcidic => l10n.fieldPhSlightlyAcidic,
        PhLevel.neutral => l10n.fieldPhNeutral,
        PhLevel.alkaline => l10n.fieldPhAlkaline,
      };
      rows.add((
        icon: Icons.science_outlined,
        label: l10n.fieldFactPh,
        value: l10n.fieldFactPhValue(word, number(ph, 1)),
        note: note,
      ));
    }
    if (soil.organicCarbonGkg case final carbon?) {
      rows.add((
        icon: Icons.compost,
        label: l10n.fieldFactOrganic,
        value: l10n.fieldFactOrganicValue(number(carbon, 1)),
        note: note,
      ));
    }
    if ((soil.sandPct, soil.clayPct) case (final sand?, final clay?)) {
      rows.add((
        icon: Icons.blur_on,
        label: l10n.fieldFactTexture,
        value: l10n.fieldFactTextureValue(number(sand, 0), number(clay, 0)),
        note: note,
      ));
    }
  }
  return rows;
}
