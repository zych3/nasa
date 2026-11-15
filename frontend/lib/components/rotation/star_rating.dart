import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

const _stars = 5;

int _halvesOf(double value) => (value.clamp(0.0, 1.0) * _stars * 2).round();

/// "Harvest quality: 3.5 out of 5 stars", for screen readers.
String starsLabel(AppLocalizations l10n, String locale, double value) =>
    l10n.harvestStars(
      NumberFormat('0.#', locale).format(_halvesOf(value) / 2),
      _stars,
    );

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final halves = _halvesOf(value);
    final locale = Localizations.localeOf(context).toString();

    return Semantics(
      label: starsLabel(AppLocalizations.of(context), locale, value),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _stars; i++)
            Icon(
              halves >= 2 * (i + 1)
                  ? Icons.star_rounded
                  : halves == 2 * i + 1
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
              size: 22,
              color: const Color(0xFFE0A100),
            ),
        ],
      ),
    );
  }
}
