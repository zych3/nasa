import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/saved_plan.dart';
import '../repositories/auth_store.dart';
import '../repositories/saved_plans_repository.dart';
import '../widgets/read_aloud_button.dart';
import 'saved_plan_page.dart';

/// "My plans": the rotation plans the signed-in user saved. Tap one to open
/// it again, or delete it.
class MyPlansPage extends StatefulWidget {
  const MyPlansPage({super.key, required this.authStore, this.repository});

  final AuthStore authStore;

  final SavedPlansRepository? repository;

  /// Opens the page on top of the app.
  static Future<void> open(BuildContext context, AuthStore store) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MyPlansPage(authStore: store)),
      );

  @override
  State<MyPlansPage> createState() => _MyPlansPageState();
}

class _MyPlansPageState extends State<MyPlansPage> {
  late final SavedPlansRepository _repo =
      widget.repository ?? SavedPlansRepository();

  List<SavedPlan> _items = const [];
  bool _loading = true;
  bool _failed = false;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _expired = false;
    });
    final token = widget.authStore.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _expired = true;
      });
      return;
    }
    try {
      final items = await _repo.list(token);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) await widget.authStore.signOut();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _expired = e.statusCode == 401;
        _failed = e.statusCode != 401;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _delete(SavedPlan item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final token = widget.authStore.token;

    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.myPlansDeleteTitle),
        content: Text(
          l10n.myPlansDeleteBody,
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(
              l10n.myPlansCancel,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              l10n.myPlansDelete,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
    if (sure != true || token == null) return;

    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    try {
      await _repo.delete(token, item.id);
      if (!mounted) return;
      setState(() => _items = [..._items.where((p) => p.id != item.id)]);
      say(l10n.myPlansDeleted);
    } on ApiException catch (e) {
      // Already gone (404) is the result the user wanted.
      if (e.statusCode == 404 && mounted) {
        setState(() => _items = [..._items.where((p) => p.id != item.id)]);
        say(l10n.myPlansDeleted);
      } else {
        say(l10n.myPlansDeleteFailed);
      }
    } catch (_) {
      say(l10n.myPlansDeleteFailed);
    }
  }

  String _route(SavedPlan item, String language) =>
      item.plan.seasons.map((s) => s.crop.nameFor(language)).join(' → ');

  String _info(AppLocalizations l10n, String locale, SavedPlan item) =>
      l10n.myPlansItemInfo(
        goalLabel(l10n, item.goal) ?? '',
        DateFormat.yMMMd(locale).format(item.createdAt.toLocal()),
      );

  String _readAloud(AppLocalizations l10n) {
    final language = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    if (_loading) return l10n.myPlansTitle;
    if (_expired) return l10n.reportSaveSessionExpired;
    if (_failed) return l10n.myPlansLoadError;
    if (_items.isEmpty) return l10n.myPlansEmpty;

    return sentencesForReading([
      l10n.myPlansTitle,
      for (final item in _items) ...[
        _info(l10n, locale, item),
        item.plan.seasons.map((s) => s.crop.nameFor(language)).join(', '),
      ],
    ]);
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
        title: Text(l10n.myPlansTitle),
        actions: [
          ReadAloudButton(text: () => _readAloud(l10n)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: _body(context, l10n)),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();

    Widget message(String text, {bool retry = false}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
            ),
            if (retry) ...[
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                onPressed: _load,
                child: Text(l10n.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_expired) return message(l10n.reportSaveSessionExpired);
    if (_failed) return message(l10n.myPlansLoadError, retry: true);
    if (_items.isEmpty) return message(l10n.myPlansEmpty);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            minTileHeight: 80,
            leading: const Icon(Icons.bookmark, size: 32),
            title: Text(
              _route(item, language),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              _info(l10n, locale, item),
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
            ),
            trailing: IconButton(
              iconSize: 28,
              tooltip: l10n.myPlansDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(item),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SavedPlanPage(saved: item),
              ),
            ),
          ),
        );
      },
    );
  }
}
