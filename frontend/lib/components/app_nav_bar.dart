import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Bottom tabs (forui): thin line on top, icon and word for each tab, so it
/// never relies on the icon or colour alone.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.theme.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: FBottomNavigationBar(
        index: selectedIndex,
        onChange: onSelected,
        safeAreaBottom: true,
        children: [
          FBottomNavigationBarItem(
            icon: const Icon(FLucideIcons.map),
            label: Text(l10n.navMap),
          ),
          FBottomNavigationBarItem(
            icon: const Icon(FLucideIcons.sprout),
            label: Text(l10n.navPlot),
          ),
          FBottomNavigationBarItem(
            icon: const Icon(FLucideIcons.layers),
            label: Text(l10n.navConditions),
          ),
        ],
      ),
    );
  }
}
