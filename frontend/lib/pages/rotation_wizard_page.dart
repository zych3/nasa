import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../components/input/plotInput/crop_multi_selector.dart';
import '../components/rotation/crop_picker_sheet.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/rotation_report.dart';
import '../repositories/auth_store.dart';
import '../repositories/crop_repository.dart';
import 'rotation_report_page.dart';

/// "Plan crop rotation": three short steps (past crops, goal, extras), one
/// question per screen, every answer optional. forui look: a thin progress
/// bar, grouped tiles, big buttons at the bottom.
class RotationWizardPage extends StatefulWidget {
  const RotationWizardPage({
    super.key,
    required this.parcel,
    required this.authStore,
  });

  final Parcel parcel;

  final AuthStore authStore;

  @override
  State<RotationWizardPage> createState() => _RotationWizardPageState();
}

class _RotationWizardPageState extends State<RotationWizardPage> {
  static const _steps = 3;
  static const _goals = ['balanced', 'soil_health', 'safe_harvest'];

  final _crops = CropRepository();
  late final Future<List<Crop>> _cropList = _crops.getCrops();
  final _ph = TextEditingController();

  int _step = 0;
  final List<String?> _past = [null, null, null];
  String? _goal;
  bool _livestock = false;
  bool _irrigation = false;
  final List<String> _excluded = [];
  bool _phInvalid = false;

  @override
  void dispose() {
    _ph.dispose();
    super.dispose();
  }

  Future<void> _pickCrop(int slot, List<Crop> crops) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CropPickerSheet(
        crops: crops,
        selectedId: _past[slot],
        canClear: _past[slot] != null,
      ),
    );
    if (picked == null) return;
    setState(() => _past[slot] = picked == cropPickerCleared ? null : picked);
  }

  void _next() {
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    final text = _ph.text.trim().replaceAll(',', '.');
    final ph = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (ph == null || ph < 3 || ph > 9)) {
      setState(() => _phInvalid = true);
      return;
    }

    final answers = RotationAnswers(
      pastCrops: [for (final id in _past) ?id],
      goal: _goal,
      excludedCrops: List.of(_excluded),
      hasLivestock: _livestock ? true : null,
      hasIrrigation: _irrigation ? true : null,
      soilPhKCl: ph,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RotationReportPage(
          parcel: widget.parcel,
          answers: answers,
          authStore: widget.authStore,
        ),
      ),
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    final last = _step == _steps - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: IconButton(
            iconSize: 24,
            tooltip: l10n.wizardBack,
            icon: const Icon(FLucideIcons.arrowLeft),
            onPressed: _back,
          ),
          title: Text(l10n.rotationStart),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // Readable line length on wide (web) screens.
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.wizardStep(_step + 1, _steps),
                          style: type.body.md.copyWith(
                            color: colors.mutedForeground,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FDeterminateProgress(
                          value: (_step + 1) / _steps,
                          semanticsLabel: l10n.wizardStep(_step + 1, _steps),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        if (_step == 0) ..._pastCropsStep(l10n),
                        if (_step == 1) ..._goalStep(l10n),
                        if (_step == 2) ..._extrasStep(l10n),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: FButton(
                        size: FButtonSizeVariant.lg,
                        onPress: _next,
                        suffix: Icon(
                          last
                              ? FLucideIcons.sparkles
                              : FLucideIcons.arrowRight,
                        ),
                        child: Flexible(
                          child: Text(
                            last ? l10n.wizardShowPlan : l10n.wizardNext,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Big question and a quiet line under it.
  List<Widget> _question(String title, String hint) {
    final theme = context.theme;
    return [
      Semantics(
        header: true,
        child: Text(
          title,
          style: theme.typography.display.xl2.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            height: 1.2,
            color: theme.colors.foreground,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        hint,
        style: theme.typography.body.md.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _pastCropsStep(AppLocalizations l10n) {
    final language = Localizations.localeOf(context).languageCode;
    final labels = [
      l10n.pastCropLast,
      l10n.pastCropBefore,
      l10n.pastCropEarlier,
    ];
    final colors = context.theme.colors;

    return [
      ..._question(l10n.pastCropsTitle, l10n.pastCropsHint),
      FutureBuilder<List<Crop>>(
        future: _cropList,
        builder: (context, snapshot) {
          final crops = [
            for (final c in snapshot.data ?? const <Crop>[])
              if (c.supportsRotation) c,
          ];
          String? nameOf(String? id) {
            if (id == null) return null;
            for (final c in crops) {
              if (c.id == id) return c.nameFor(language);
            }
            return null;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FTileGroup(
                description: Text(l10n.wizardOptional),
                children: [
                  for (var i = 0; i < _past.length; i++)
                    FTile(
                      prefix: Icon(
                        _past[i] == null
                            ? FLucideIcons.circlePlus
                            : FLucideIcons.sprout,
                        color: _past[i] == null
                            ? colors.mutedForeground
                            : colors.primary,
                      ),
                      title: Text(labels[i]),
                      subtitle: Text(nameOf(_past[i]) ?? l10n.pastCropChoose),
                      suffix: const Icon(FLucideIcons.chevronRight),
                      onPress: crops.isEmpty ? null : () => _pickCrop(i, crops),
                    ),
                ],
              ),
              if (snapshot.connectionState != ConnectionState.done) ...[
                const SizedBox(height: 12),
                const FProgress(),
              ],
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _goalStep(AppLocalizations l10n) {
    final colors = context.theme.colors;

    FTile tile(String? goal, String title, String? hint, IconData icon) {
      final selected = _goal == goal;
      return FTile(
        selected: selected,
        prefix: Icon(icon, color: selected ? colors.primary : null),
        title: Text(title),
        subtitle: hint == null ? null : Text(hint),
        suffix: selected
            ? Icon(FLucideIcons.circleCheck, color: colors.primary)
            : const Icon(FLucideIcons.circle),
        semanticsLabel: title,
        onPress: () => setState(() => _goal = goal),
      );
    }

    return [
      ..._question(l10n.goalTitle, l10n.wizardOptional),
      FTileGroup(
        children: [
          tile(null, l10n.goalNoPreference, null, FLucideIcons.circleHelp),
          for (final goal in _goals)
            tile(
              goal,
              goalLabel(l10n, goal)!,
              goalHint(l10n, goal),
              switch (goal) {
                'soil_health' => FLucideIcons.mountain,
                'safe_harvest' => FLucideIcons.shieldCheck,
                _ => FLucideIcons.scale,
              },
            ),
        ],
      ),
    ];
  }

  List<Widget> _extrasStep(AppLocalizations l10n) => [
    ..._question(l10n.extrasTitle, l10n.wizardOptional),
    FCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FSwitch(
              label: Text(l10n.extrasLivestock),
              value: _livestock,
              onChange: (v) => setState(() => _livestock = v),
            ),
            const SizedBox(height: 12),
            const FDivider(),
            const SizedBox(height: 12),
            FSwitch(
              label: Text(l10n.extrasIrrigation),
              value: _irrigation,
              onChange: (v) => setState(() => _irrigation = v),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 24),
    FTextField(
      control: FTextFieldControl.managed(
        controller: _ph,
        onChange: (_) {
          if (_phInvalid) setState(() => _phInvalid = false);
        },
      ),
      size: FTextFieldSizeVariant.lg,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: Text(l10n.extrasPhLabel),
      hint: l10n.extrasPhHint,
      error: _phInvalid ? Text(l10n.extrasPhInvalid) : null,
    ),
    const SizedBox(height: 24),
    CropMultiSelector(
      onlyRotationCrops: true,
      label: l10n.extrasExcludedLabel,
      selectedCrops: _excluded,
      onCropToggled: (id, selected) => setState(() {
        if (selected) {
          _excluded.add(id);
        } else {
          _excluded.remove(id);
        }
      }),
    ),
  ];
}
