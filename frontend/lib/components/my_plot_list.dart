import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/parcel.dart';
import '../repositories/my_parcels_store.dart';
import '../repositories/selected_plot_store.dart';

String _name(AppLocalizations l10n, Parcel parcel) =>
    parcel.address ?? l10n.parcelNumber(parcel.id);

Future<bool> _ask(
  BuildContext context, {
  required String title,
  required String body,
  required String yes,
  required String no,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(no, style: const TextStyle(fontSize: 18)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(yes, style: const TextStyle(fontSize: 18)),
        ),
      ],
    ),
  );
  return answer == true;
}

/// A parcel was picked (on the map or by address): asks "is this your
/// parcel?". "Yes" adds it to "My parcels" and makes it the active one, "No"
/// changes nothing. A parcel that is already on the list is just made active.
/// Returns whether the parcel is now the active one.
Future<bool> offerMyParcel(
  BuildContext context, {
  required Parcel parcel,
  required SelectedPlotStore store,
  MyParcelsStore? parcels,
}) async {
  final mine = parcels ?? MyParcelsStore.shared;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!mine.contains(parcel.id)) {
    final yes = await _ask(
      context,
      title: l10n.myParcelAskTitle,
      body: l10n.myParcelAskBody(_name(l10n, parcel)),
      yes: l10n.myParcelYes,
      no: l10n.myParcelNo,
    );
    if (!yes) return false;
    await mine.add(parcel);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.myParcelAdded)));
  }
  await store.select(parcel);
  return true;
}

/// Big tappable cards, one per parcel of the user. Tap = work on this parcel;
/// swipe to the right = remove it (after asking).
class MyPlotList extends StatelessWidget {
  const MyPlotList({
    super.key,
    required this.parcels,
    required this.onSelected,
    required this.onRemoved,
    this.selectedId,
  });

  final List<Parcel> parcels;
  final String? selectedId;
  final ValueChanged<Parcel> onSelected;
  final ValueChanged<Parcel> onRemoved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final parcel in parcels)
          Dismissible(
            key: ValueKey('my-parcel-${parcel.id}'),
            direction: DismissDirection.startToEnd,
            confirmDismiss: (_) => _ask(
              context,
              title: l10n.myParcelRemoveTitle,
              body: l10n.myParcelRemoveBody(_name(l10n, parcel)),
              yes: l10n.myParcelRemoveYes,
              no: l10n.myParcelNo,
            ),
            onDismissed: (_) => onRemoved(parcel),
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 32,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            child: Card(
              child: ListTile(
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                selected: parcel.id == selectedId,
                leading: Icon(
                  parcel.id == selectedId
                      ? Icons.check_circle
                      : Icons.landscape_outlined,
                  size: 32,
                ),
                title: Text(
                  _name(l10n, parcel),
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(l10n.parcelNumber(parcel.id)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelected(parcel),
              ),
            ),
          ),
      ],
    );
  }
}
