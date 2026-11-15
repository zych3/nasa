import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../l10n/rotation_text.dart';
import '../models/local_plan.dart';
import '../repositories/auth_store.dart';
import '../repositories/local_plans_store.dart';
import 'saved_plan_page.dart';

/// "My plans": the rotation plans saved on this phone (and, when signed in,
/// copied to the account). Tap one to open it again, or delete it.
class MyPlansPage extends StatefulWidget {
  const MyPlansPage({super.key, this.authStore, this.plans});

  /// Only used to say where the plans are kept.
  final AuthStore? authStore;

  final LocalPlansStore? plans;

  /// Opens the page on top of the app.
  static Future<void> open(BuildContext context, AuthStore store) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MyPlansPage(authStore: store)),
      );

  @override
  State<MyPlansPage> createState() => _MyPlansPageState();
}

class _MyPlansPageState extends State<MyPlansPage> {
  late final LocalPlansStore _store = widget.plans ?? LocalPlansStore.shared;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<LocalPlan> get _items => _store.items;

  Future<void> _delete(LocalPlan item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

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
    if (sure != true) return;

    try {
      await _store.remove(item);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.myPlansDeleted)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.myPlansDeleteFailed)));
    }
  }

  String _route(LocalPlan item, String language) =>
      item.plan.seasons.map((s) => s.crop.nameFor(language)).join(' → ');

  String _info(AppLocalizations l10n, String locale, LocalPlan item) =>
      l10n.myPlansItemInfo(
        goalLabel(l10n, item.goal) ?? '',
        DateFormat.yMMMd(locale).format(item.createdAt.toLocal()),
      );

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
      ),
      body: SafeArea(child: _body(context, l10n)),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.myPlansEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
          ),
        ),
      );
    }

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
                builder: (_) => SavedPlanPage(saved: item.toSavedPlan()),
              ),
            ),
          ),
        );
      },
    );
  }
}
