import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

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

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.map_outlined),
          selectedIcon: const Icon(Icons.map),
          label: l10n.navMap,
        ),
        NavigationDestination(
          icon: const Icon(Icons.agriculture_outlined),
          selectedIcon: const Icon(Icons.agriculture),
          label: l10n.navPlot,
        ),
        NavigationDestination(
          icon: const Icon(Icons.layers_outlined),
          selectedIcon: const Icon(Icons.layers),
          label: l10n.navConditions,
        ),
      ],
    );
  }
}
