import 'package:material_ui/material_ui.dart';

import '../components/crop_summary_card.dart';
import '../components/map_button.dart';
import '../l10n/app_localizations.dart';
import '../models/trending_crop.dart';
import '../repositories/trends_repository.dart';

/// "Popular crops" tab: list of crops trending near the user's parcel.
class TrendingCropsPage extends StatefulWidget {
  const TrendingCropsPage({super.key, this.repository, this.parcelId});

  /// Injectable for tests; defaults to mock data until the backend exists.
  final TrendsRepository? repository;
  final String? parcelId;

  @override
  State<TrendingCropsPage> createState() => _TrendingCropsPageState();
}

class _TrendingCropsPageState extends State<TrendingCropsPage> {
  late final TrendsRepository _repository =
      widget.repository ?? TrendsRepository();
  Future<List<TrendingCrop>>? _future;
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Content comes translated from the API, so reload when language changes.
    final lang = Localizations.localeOf(context).languageCode;
    if (lang != _languageCode) {
      _languageCode = lang;
      _future = _load();
    }
  }

  Future<List<TrendingCrop>> _load() => _repository.getTrendingCrops(
    parcelId: widget.parcelId,
    languageCode: _languageCode!,
  );

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future.catchError((_) => <TrendingCrop>[]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<List<TrendingCrop>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _Message(
            icon: Icons.cloud_off,
            text: l10n.trendsLoadError,
            actionLabel: l10n.tryAgain,
            onAction: _refresh,
          );
        }

        final crops = snapshot.data ?? const [];
        if (crops.isEmpty) {
          return _Message(
            icon: Icons.grass,
            text: l10n.trendsEmpty,
            actionLabel: l10n.tryAgain,
            onAction: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Room for the language button floating in the top corner.
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: MapButton.reservedEnd - 16,
                ),
                child: Text(
                  l10n.trendsTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.trendsIntro, style: theme.textTheme.bodyLarge),
              if (_repository.useMock) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.demoDataNotice,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              for (final crop in crops) ...[
                CropSummaryCard(crop: crop),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
