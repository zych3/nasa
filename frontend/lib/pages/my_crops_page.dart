import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/crop.dart';
import '../models/user_crop.dart';
import '../repositories/auth_store.dart';
import '../repositories/crop_repository.dart';
import '../repositories/selected_plot_store.dart';
import '../repositories/user_crop_repository.dart';
import '../widgets/read_aloud_button.dart';
import 'user_crop_form_page.dart';

/// "My crops": the signed-in user's saved crops with their places. Each one
/// has an "active" checkbox and can be changed; "Add a crop" saves a crop for
/// the field chosen on the map. Opened from "Account".
class MyCropsPage extends StatefulWidget {
  const MyCropsPage({
    super.key,
    required this.auth,
    required this.plotStore,
    this.repository,
    this.cropRepository,
  });

  final AuthStore auth;
  final SelectedPlotStore plotStore;

  /// For tests; by default the backend.
  final UserCropRepository? repository;
  final CropRepository? cropRepository;

  static Future<void> open(
    BuildContext context, {
    required AuthStore auth,
    required SelectedPlotStore plotStore,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MyCropsPage(auth: auth, plotStore: plotStore),
    ),
  );

  @override
  State<MyCropsPage> createState() => _MyCropsPageState();
}

class _MyCropsPageState extends State<MyCropsPage> {
  late final UserCropRepository _repo =
      widget.repository ?? UserCropRepository(auth: widget.auth);
  late final CropRepository _cropRepo =
      widget.cropRepository ?? CropRepository();

  List<UserCrop>? _items;
  List<Crop> _crops = const [];
  UserCropError? _error;

  /// Entry whose checkbox is being saved.
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([_repo.list(), _cropRepo.getCrops()]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<UserCrop>;
        _crops = results[1] as List<Crop>;
      });
    } on UserCropException catch (e) {
      if (mounted) setState(() => _error = e.error);
    }
  }

  Future<void> _setActive(UserCrop item, bool active) async {
    setState(() => _savingId = item.id);
    try {
      final saved = await _repo.update(item.id, isActive: active);
      if (!mounted) return;
      setState(() => _replace(saved));
    } on UserCropException catch (e) {
      if (mounted) _showError(e.error);
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _openForm({UserCrop? existing}) async {
    final saved = await Navigator.of(context).push<UserCrop>(
      MaterialPageRoute(
        builder: (_) => UserCropFormPage(
          repository: _repo,
          crops: _crops,
          parcel: widget.plotStore.parcel,
          existing: existing,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      if (existing == null) {
        _items = [saved, ...?_items];
      } else {
        _replace(saved);
      }
    });
  }

  void _replace(UserCrop saved) {
    _items = [
      for (final item in _items ?? const <UserCrop>[])
        item.id == saved.id ? saved : item,
    ];
  }

  void _showError(UserCropError error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(userCropErrorText(context, error))));
  }

  String _cropName(String cropId, String language, AppLocalizations l10n) {
    for (final crop in _crops) {
      if (crop.id == cropId) return crop.nameFor(language);
    }
    return l10n.myCropsUnknownCrop;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final error = _error;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCropsTitle),
        actions: [
          ReadAloudButton(
            text: () => sentencesForReading([
              l10n.myCropsTitle,
              l10n.myCropsIntro,
              if (items != null && items.isEmpty) l10n.myCropsEmpty,
            ]),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: error != null
            ? _Message(
                icon: Icons.cloud_off,
                text: userCropErrorText(context, error),
                action: error == UserCropError.signedOut
                    ? null
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.myCropsRetry),
                      ),
              )
            : items == null
            ? const Center(child: CircularProgressIndicator())
            : _buildList(context, items),
      ),
      bottomNavigationBar: items == null || error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.myCropsAdd),
                ),
              ),
            ),
    );
  }

  Widget _buildList(BuildContext context, List<UserCrop> items) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.myCropsIntro,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _Message(icon: Icons.grass, text: l10n.myCropsEmpty)
        else
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.grass,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        _cropName(item.cropId, language, l10n),
                        style: theme.textTheme.titleLarge,
                      ),
                      subtitle: Text(
                        placeText(context, item.label, item.point),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    CheckboxListTile(
                      value: item.isActive,
                      onChanged: _savingId == item.id
                          ? null
                          : (v) => _setActive(item, v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        l10n.myCropsActive,
                        style: const TextStyle(fontSize: 18),
                      ),
                      subtitle: Text(
                        item.isActive
                            ? l10n.myCropsActiveOn
                            : l10n.myCropsActiveOff,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: () => _openForm(existing: item),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.myCropsEdit),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// The place of an entry: the user's label, otherwise the coordinates.
String placeText(BuildContext context, String? label, LatLng point) {
  if (label != null && label.isNotEmpty) return label;
  final l10n = AppLocalizations.of(context);
  final format = NumberFormat(
    '0.0000',
    Localizations.localeOf(context).toLanguageTag(),
  );
  return l10n.myCropsCoordinates(
    format.format(point.latitude),
    format.format(point.longitude),
  );
}

/// Words for a failed "my crops" call.
String userCropErrorText(BuildContext context, UserCropError error) {
  final l10n = AppLocalizations.of(context);
  return switch (error) {
    UserCropError.signedOut => l10n.myCropsErrorSignedOut,
    UserCropError.rejected => l10n.myCropsErrorRejected,
    UserCropError.serverUnavailable => l10n.authErrorServer,
    UserCropError.noConnection => l10n.authErrorNoConnection,
  };
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
          ),
          if (action case final action?) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }
}
