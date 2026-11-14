import 'package:material_ui/material_ui.dart';

import '../components/input/plotInput.dart';
import '../l10n/app_localizations.dart';

/// "Moje pole" – plot data page. Layout only; values are placeholders.
class PlotPage extends StatelessWidget {
  const PlotPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header: plot name, area, location
        Card(
          child: ListTile(
            leading: const Icon(Icons.agriculture, size: 40),
            title: Text(l10n.plotName, style: theme.textTheme.titleLarge),
            subtitle: Text(l10n.plotSummary('—', '—')),
          ),
        ),
        const SizedBox(height: 16),

        // Map preview placeholder
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.map_outlined, size: 48),
        ),
        const SizedBox(height: 24),

        // Plot input form (left as-is)
        Text(l10n.plotDataSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        PlotInput(onSubmitPlot: (_) {}),
        const SizedBox(height: 24),

        // Info cards
        Text(l10n.infoSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.landscape_outlined,
                label: l10n.soil,
                value: '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(icon: Icons.grass, label: l10n.crop, value: '—'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.water_drop_outlined,
                label: l10n.moisture,
                value: '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                icon: Icons.thermostat_outlined,
                label: l10n.temperature,
                value: '—',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelMedium),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
