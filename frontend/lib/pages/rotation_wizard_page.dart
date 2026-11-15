import 'package:material_ui/material_ui.dart';

import '../components/input/plotInput/crop_multi_selector.dart';
import '../components/rotation/crop_picker_sheet.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/rotation_report.dart';
import '../repositories/crop_repository.dart';
import 'rotation_report_page.dart';

class RotationWizardPage extends StatefulWidget {
  const RotationWizardPage({super.key, required this.parcel});

  final Parcel parcel;

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

  bool get _canContinue => _step != 0 || _past[0] != null;

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
        builder: (_) =>
            RotationReportPage(parcel: widget.parcel, answers: answers),
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
    final theme = Theme.of(context);
    final last = _step == _steps - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            iconSize: 28,
            tooltip: l10n.wizardBack,
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(l10n.rotationStart),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.wizardStep(_step + 1, _steps),
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (_step + 1) / _steps,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_step == 0) ..._pastCropsStep(l10n, theme),
                    if (_step == 1) ..._goalStep(l10n, theme),
                    if (_step == 2) ..._extrasStep(l10n, theme),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_canContinue)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.pastCropRequired,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        textStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontSize: 20),
                      ),
                      onPressed: _canContinue ? _next : null,
                      child: Text(last ? l10n.wizardShowPlan : l10n.wizardNext),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text, ThemeData theme) =>
      Text(text, style: theme.textTheme.headlineSmall);

  List<Widget> _pastCropsStep(AppLocalizations l10n, ThemeData theme) {
    final language = Localizations.localeOf(context).languageCode;
    final labels = [
      l10n.pastCropLast,
      l10n.pastCropBefore,
      l10n.pastCropEarlier,
    ];

    return [
      _title(l10n.pastCropsTitle, theme),
      const SizedBox(height: 8),
      Text(
        l10n.pastCropsHint,
        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
      ),
      const SizedBox(height: 16),
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
            children: [
              for (var i = 0; i < _past.length; i++)
                Card(
                  child: ListTile(
                    minTileHeight: 80,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Icon(
                      _past[i] == null ? Icons.add_circle_outline : Icons.grass,
                      size: 32,
                    ),
                    title: Text(
                      labels[i],
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
                    ),
                    subtitle: Text(
                      nameOf(_past[i]) ?? l10n.pastCropChoose,
                      style: theme.textTheme.titleLarge,
                    ),
                    trailing: i == 0 ? null : Text(l10n.wizardOptional),
                    onTap: crops.isEmpty ? null : () => _pickCrop(i, crops),
                  ),
                ),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _goalStep(AppLocalizations l10n, ThemeData theme) {
    Widget card(String? goal, String title, String? hint, IconData icon) {
      final selected = _goal == goal;
      return Card(
        color: selected ? theme.colorScheme.primaryContainer : null,
        child: ListTile(
          minTileHeight: 80,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(selected ? Icons.check_circle : icon, size: 32),
          title: Text(title, style: theme.textTheme.titleLarge),
          subtitle: hint == null
              ? null
              : Text(
                  hint,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                ),
          onTap: () => setState(() => _goal = goal),
        ),
      );
    }

    return [
      _title(l10n.goalTitle, theme),
      const SizedBox(height: 4),
      Text(l10n.wizardOptional, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 16),
      card(null, l10n.goalNoPreference, null, Icons.help_outline),
      for (final goal in _goals)
        card(goal, goalLabel(l10n, goal)!, goalHint(l10n, goal), switch (goal) {
          'soil_health' => Icons.landscape_outlined,
          'safe_harvest' => Icons.shield_outlined,
          _ => Icons.balance,
        }),
    ];
  }

  List<Widget> _extrasStep(AppLocalizations l10n, ThemeData theme) => [
    _title(l10n.extrasTitle, theme),
    const SizedBox(height: 4),
    Text(l10n.wizardOptional, style: theme.textTheme.bodyLarge),
    const SizedBox(height: 8),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.extrasLivestock, style: theme.textTheme.titleMedium),
      value: _livestock,
      onChanged: (v) => setState(() => _livestock = v),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.extrasIrrigation, style: theme.textTheme.titleMedium),
      value: _irrigation,
      onChanged: (v) => setState(() => _irrigation = v),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _ph,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        labelText: l10n.extrasPhLabel,
        hintText: l10n.extrasPhHint,
        errorText: _phInvalid ? l10n.extrasPhInvalid : null,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        if (_phInvalid) setState(() => _phInvalid = false);
      },
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
