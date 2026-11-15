import 'package:material_ui/material_ui.dart';

import '../components/rotation/plan_timeline.dart';
import '../components/rotation/rating_row.dart';
import '../components/rotation/rotation_details.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/rotation_report.dart';
import '../repositories/crop_repository.dart';
import '../repositories/rotation_repository.dart';

class RotationReportPage extends StatefulWidget {
  const RotationReportPage({
    super.key,
    required this.parcel,
    required this.answers,
    this.repository,
  });

  final Parcel parcel;
  final RotationAnswers answers;

  final RotationRepository? repository;

  @override
  State<RotationReportPage> createState() => _RotationReportPageState();
}

class _RotationReportPageState extends State<RotationReportPage> {
  late final RotationRepository _repository =
      widget.repository ?? RotationRepository();
  late Future<RotationReport> _report = _load();
  List<Crop> _catalogue = const [];

  String? _goal;

  static const _headline = ['harvest', 'humus', 'disease', 'water'];

  Future<RotationReport> _load() {
    CropRepository().getCrops().then((c) {
      if (mounted) setState(() => _catalogue = c);
    });
    return _repository.getReport(
      parcelId: widget.parcel.id,
      lat: widget.parcel.center.latitude,
      lon: widget.parcel.center.longitude,
      answers: widget.answers,
    );
  }

  void _retry() => setState(() {
    _goal = null;
    _report = _load();
  });

  Map<String, String> _names(RotationReport report, String language) {
    final names = <String, String>{
      for (final c in _catalogue) c.id: c.nameFor(language),
    };
    for (final g in report.goals) {
      for (final plan in [g.best, ...g.alternatives]) {
        for (final s in plan.seasons) {
          names[s.crop.id] = s.crop.nameFor(language);
          if (s.catchCrop != null) {
            names[s.catchCrop!.id] = s.catchCrop!.nameFor(language);
          }
        }
      }
    }
    return names;
  }

  void _showDetails(
    RotationReport report,
    String goal,
    Map<String, String> names,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => RotationDetails(
          report: report,
          goal: goal,
          cropNames: names,
          controller: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          iconSize: 28,
          tooltip: l10n.wizardBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.reportTitle),
      ),
      body: SafeArea(
        child: FutureBuilder<RotationReport>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _message(context, l10n.reportLoading, busy: true);
            }
            if (snapshot.hasError) {
              return _message(context, l10n.reportLoadError, onRetry: _retry);
            }
            return _content(context, snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context,
    String text, {
    bool busy = false,
    VoidCallback? onRetry,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _note(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
          ),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context, RotationReport report) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final names = _names(report, language);
    final goal = _goal ?? report.mainGoal;
    final plans = report.plansFor(goal);
    final warnings = [
      for (final w in report.warnings) ?warningText(l10n, w, (id) => names[id]),
    ];

    if (plans == null || !report.hasPlan) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.reportNoPlan,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 16),
          for (final text in warnings) _note(theme, text),
        ],
      );
    }

    final goalsToPick = [
      for (final g in report.goals)
        if (goalLabel(l10n, g.goal) != null) g.goal,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (goalsToPick.length > 1) ...[
          Text(
            l10n.reportGoalPicker,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in goalsToPick)
                ChoiceChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  label: Text(
                    goalLabel(l10n, g)!,
                    style: const TextStyle(fontSize: 18),
                  ),
                  selected: g == plans.goal,
                  onSelected: (_) => setState(() => _goal = g),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        Text(
          plans.goal == report.mainGoal
              ? l10n.reportMainTitle
              : l10n.reportSowNext,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        PlanTimeline(plan: plans.best),

        if (!plans.best.isFeasible)
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, size: 28),
              title: Text(
                l10n.planNotFeasible,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
            ),
          ),

        const SizedBox(height: 16),
        Text(l10n.reportQualityTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        for (final key in _headline)
          if (plans.best.score(key) != null && scoreLabel(l10n, key) != null)
            RatingRow(
              label: scoreLabel(l10n, key)!,
              rating: plans.best.score(key)!,
            ),

        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final text in warnings) _note(theme, text),
        ],

        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 18),
          ),
          icon: const Icon(Icons.info_outline),
          label: Text(l10n.moreDetails),
          onPressed: () => _showDetails(report, plans.goal, names),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
