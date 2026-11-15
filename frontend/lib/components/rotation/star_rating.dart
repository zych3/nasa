import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value});

  final double value;

  static const _stars = 5;

  @override
  Widget build(BuildContext context) {
    final halves = (value.clamp(0.0, 1.0) * _stars * 2).round();
    final locale = Localizations.localeOf(context).toString();

    return Semantics(
      label: AppLocalizations.of(context)
          .harvestStars(NumberFormat('0.#', locale).format(halves / 2), _stars),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _stars; i++)
            Icon(
              halves >= 2 * (i + 1)
                  ? Icons.star
                  : halves == 2 * i + 1
                  ? Icons.star_half
                  : Icons.star_border,
              size: 28,
              color: Colors.amber.shade800,
            ),
        ],
      ),
    );
  }
}
