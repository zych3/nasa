import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/rotation/climate_trends_section.dart';
import '../components/rotation/plan_timeline.dart';
import '../components/rotation/rating_row.dart';
import '../components/rotation/rotation_details.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/climate_trends.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/rotation_report.dart';
import '../repositories/auth_store.dart';
import '../repositories/climate_trends_repository.dart';
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
    this.climateRepository,
  });

  final Parcel parcel;
  final RotationAnswers answers;

  /// Saving never needs an account; it only decides where the plan is kept
  /// (the phone, and the account too when signed in).
  final AuthStore authStore;

  final RotationRepository? repository;

  /// Where saved plans go (the app's own by default).
  final LocalPlansStore? plans;

  /// Long-term climate changes shown under the plan.
  final ClimateTrendsRepository? climateRepository;

  @override
  State<RotationReportPage> createState() => _RotationReportPageState();
}

class _RotationReportPageState extends State<RotationReportPage> {
  late final RotationRepository _repository =
      widget.repository ?? RotationRepository();
  late final LocalPlansStore _plans = widget.plans ?? LocalPlansStore.shared;
  late Future<RotationReport> _report = _load();
  List<Crop> _catalogue = const [];

  /// Loaded once, next to the plan: the plan never waits for it, and a
  /// failure only leaves the climate section out.
  late final Future<ClimateTrends?> _climate;

  String? _goal;

  /// The plan the user picked in "More details" (null: the recommended one).
  RotationPlan? _choice;

  /// Plans already saved, so the button says so.
  final Set<RotationPlan> _saved = {};
  bool _saving = false;

  static const _headline = ['harvest', 'humus', 'disease', 'water'];

  @override
  void initState() {
    super.initState();
    _climate = (widget.climateRepository ?? ClimateTrendsRepository())
        .getTrends(
          parcelId: widget.parcel.id,
          lat: widget.parcel.center.latitude,
          lon: widget.parcel.center.longitude,
        );
  }

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
      backgroundColor: context.theme.colors.background,
      appBar: AppBar(
        leading: IconButton(
          iconSize: 24,
          tooltip: l10n.wizardBack,
          icon: const Icon(FLucideIcons.arrowLeft),
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
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                // Readable line length on wide (web) screens.
                constraints: const BoxConstraints(maxWidth: 640),
                child: _content(context, snapshot.data!),
              ),
            );
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
    final theme = context.theme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (busy) ...[
                const Center(child: FCircularProgress()),
                const SizedBox(height: 20),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.typography.body.md.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ] else
                FAlert(
                  variant: FAlertVariant.destructive,
                  icon: const Icon(FLucideIcons.cloudOff),
                  title: Text(text),
                ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FButton(
                  size: FButtonSizeVariant.lg,
                  onPress: onRetry,
                  prefix: const Icon(FLucideIcons.refreshCw),
                  child: Text(AppLocalizations.of(context).tryAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Small grey heading above a group ("PLAN QUALITY").
  Widget _sectionLabel(String text) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.typography.body.md.copyWith(
            color: theme.colors.mutedForeground,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, RotationReport report) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final language = Localizations.localeOf(context).languageCode;
    final names = _names(report, language);
    final goal = _goal ?? report.mainGoal;
    final plans = report.plansFor(goal);
    final warnings = [
      for (final w in report.warnings) ?warningText(l10n, w, (id) => names[id]),
    ];

    Widget warningsCard() => FCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final text in warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        FLucideIcons.info,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: type.body.md.copyWith(color: colors.foreground),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (plans == null || !report.hasPlan) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FAlert(
            icon: const Icon(FLucideIcons.circleAlert),
            title: Text(l10n.reportNoPlan),
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            warningsCard(),
          ],
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
    final saved = _saved.contains(plan);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          (plans.goal == report.mainGoal
              ? l10n.reportMainTitle
              : l10n.reportSowNext),
          style: type.body.md.copyWith(
            color: colors.mutedForeground,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            plan.seasons.map((s) => s.crop.nameFor(language)).join(' → '),
            style: type.display.xl2.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              height: 1.2,
              color: colors.foreground,
            ),
          ),
        ),

        if (goalsToPick.length > 1) ...[
          const SizedBox(height: 20),
          Text(
            l10n.reportGoalPicker,
            style: type.body.md.copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in goalsToPick)
                FButton(
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  variant: g == plans.goal
                      ? FButtonVariant.primary
                      : FButtonVariant.outline,
                  selected: g == plans.goal,
                  prefix: g == plans.goal
                      ? const Icon(FLucideIcons.check)
                      : null,
                  onPress: () => setState(() {
                    _goal = g;
                    _choice = null;
                  }),
                  child: Text(goalLabel(l10n, g)!),
                ),
            ],
          ),
        ],

        const SizedBox(height: 20),
        if (optionNumber >= 0) ...[
          FAlert(
            icon: const Icon(FLucideIcons.arrowLeftRight),
            title: Text(l10n.reportChosenOption(optionNumber + 1)),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FButton(
                variant: FButtonVariant.ghost,
                size: FButtonSizeVariant.sm,
                mainAxisSize: MainAxisSize.min,
                onPress: () => setState(() => _choice = null),
                child: Text(l10n.reportBackToBest),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        PlanTimeline(plan: plan),

        if (!plan.isFeasible) ...[
          const SizedBox(height: 12),
          FAlert(
            variant: FAlertVariant.destructive,
            icon: const Icon(FLucideIcons.triangleAlert),
            title: Text(l10n.planNotFeasible),
          ),
        ],

        _sectionLabel(l10n.reportQualityTitle),
        FCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final key in _headline)
                  if (plan.score(key) != null && scoreLabel(l10n, key) != null)
                    RatingRow(
                      label: scoreLabel(l10n, key)!,
                      rating: plan.score(key)!,
                    ),
              ],
            ),
          ),
        ),

        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          warningsCard(),
        ],

        const SizedBox(height: 28),
        FButton(
          size: FButtonSizeVariant.lg,
          onPress: _saving || saved ? null : () => _save(plans, plan),
          prefix: _saving
              ? const FCircularProgress()
              : Icon(saved ? FLucideIcons.circleCheck : FLucideIcons.bookmark),
          child: Flexible(
            child: Text(
              saved ? l10n.reportPlanSaved : l10n.reportSavePlan,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FButton(
          size: FButtonSizeVariant.lg,
          variant: FButtonVariant.outline,
          onPress: () => _showDetails(report, plans.goal, plan, names),
          prefix: const Icon(FLucideIcons.listTree),
          child: Flexible(
            child: Text(l10n.moreDetails, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 10),
        // Always there: planning can end without saving anything.
        FButton(
          size: FButtonSizeVariant.lg,
          variant: FButtonVariant.ghost,
          onPress: _finish,
          prefix: const Icon(FLucideIcons.check),
          child: Flexible(
            child: Text(l10n.reportDone, textAlign: TextAlign.center),
          ),
        ),
        ClimateTrendsSection(future: _climate),
      ],
    );
  }
}
