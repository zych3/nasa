import 'package:material_ui/material_ui.dart';

import '../components/rotation/plan_timeline.dart';
import '../components/rotation/rating_row.dart';
import '../components/rotation/rotation_details.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/rotation_report.dart';
import '../repositories/auth_store.dart';
import '../repositories/crop_repository.dart';
import '../repositories/local_plans_store.dart';
import '../repositories/rotation_repository.dart';

class RotationReportPage extends StatefulWidget {
  const RotationReportPage({
    super.key,
    required this.parcel,
    required this.answers,
    required this.authStore,
    this.repository,
    this.plans,
  });

  final Parcel parcel;
  final RotationAnswers answers;

  /// Saving never needs an account; it only decides where the plan is kept
  /// (the phone, and the account too when signed in).
  final AuthStore authStore;

  final RotationRepository? repository;

  /// Where saved plans go (the app's own by default).
  final LocalPlansStore? plans;

  @override
  State<RotationReportPage> createState() => _RotationReportPageState();
}

class _RotationReportPageState extends State<RotationReportPage> {
  late final RotationRepository _repository =
      widget.repository ?? RotationRepository();
  late final LocalPlansStore _plans = widget.plans ?? LocalPlansStore.shared;
  late Future<RotationReport> _report = _load();
  List<Crop> _catalogue = const [];

  String? _goal;

  /// The plan the user picked in "More details" (null: the recommended one).
  RotationPlan? _choice;

  /// Plans already saved, so the button says so.
  final Set<RotationPlan> _saved = {};
  bool _saving = false;

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
    _choice = null;
    _saved.clear();
    _report = _load();
  });

  /// The plan shown for [plans]: the user's pick when it belongs to this goal,
  /// otherwise the recommended one.
  RotationPlan _planFor(GoalPlans plans) {
    final choice = _choice;
    if (choice != null &&
        [plans.best, ...plans.alternatives].any((p) => identical(p, choice))) {
      return choice;
    }
    return plans.best;
  }

  /// Keeps [plan] on the phone; with an account it is copied there too.
  /// Never asks the user to sign in.
  Future<void> _save(GoalPlans plans, RotationPlan plan) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final signedIn = widget.authStore.status == AuthStatus.signedIn;

    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    setState(() => _saving = true);
    try {
      final kept = await _plans.add(
        parcelId: widget.parcel.id,
        lat: widget.parcel.center.latitude,
        lon: widget.parcel.center.longitude,
        goal: plans.goal,
        plan: plan,
        answers: widget.answers,
      );
      if (!mounted) return;
      if (kept) {
        setState(() => _saved.add(plan));
        say(signedIn ? l10n.reportSaveDoneAccount : l10n.reportSaveDone);
      } else {
        say(l10n.reportSaveTooMany);
      }
    } catch (_) {
      say(l10n.reportSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Leaves the planning and goes back to the start of the app.
  void _finish() => Navigator.of(context).popUntil((route) => route.isFirst);

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
    RotationPlan shown,
    Map<String, String> names,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => RotationDetails(
          report: report,
          goal: goal,
          shown: shown,
          cropNames: names,
          controller: controller,
          onChoose: (chosenGoal, plan) {
            Navigator.of(sheetContext).pop();
            setState(() {
              _goal = chosenGoal;
              _choice = plan;
            });
          },
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
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 20),
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

    final plan = _planFor(plans);
    final optionNumber = plans.alternatives.indexWhere(
      (p) => identical(p, plan),
    );
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
                  onSelected: (_) => setState(() {
                    _goal = g;
                    _choice = null;
                  }),
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
        if (optionNumber >= 0) ...[
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.swap_horiz, size: 28),
              title: Text(
                l10n.reportChosenOption(optionNumber + 1),
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              ),
              trailing: TextButton(
                onPressed: () => setState(() => _choice = null),
                child: Text(
                  l10n.reportBackToBest,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ],
        PlanTimeline(plan: plan),

        if (!plan.isFeasible)
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
          if (plan.score(key) != null && scoreLabel(l10n, key) != null)
            RatingRow(label: scoreLabel(l10n, key)!, rating: plan.score(key)!),

        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final text in warnings) _note(theme, text),
        ],

        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 20),
          ),
          icon: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Icon(
                  _saved.contains(plan) ? Icons.check_circle : Icons.bookmark,
                  size: 28,
                ),
          label: Text(
            _saved.contains(plan) ? l10n.reportPlanSaved : l10n.reportSavePlan,
          ),
          onPressed: _saving || _saved.contains(plan)
              ? null
              : () => _save(plans, plan),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 18),
          ),
          icon: const Icon(Icons.info_outline),
          label: Text(l10n.moreDetails),
          onPressed: () => _showDetails(report, plans.goal, plan, names),
        ),
        const SizedBox(height: 12),
        // Always there: planning can end without saving anything.
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 18),
          ),
          icon: const Icon(Icons.check),
          label: Text(l10n.reportDone),
          onPressed: _finish,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
