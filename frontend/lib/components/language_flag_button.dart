import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../pages/settings_page.dart';
import '../repositories/settings_store.dart';

/// Gear that opens the settings (language, frost alerts).
class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.settings,
    required this.onLocaleChanged,
  });

  final SettingsStore settings;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).settings,
      iconSize: 32,
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsPage(
            settings: settings,
            onLocaleChanged: onLocaleChanged,
          ),
        ),
      ),
      icon: const Icon(Icons.settings),
    );
  }
}

/// Small flag of a language, for the language list in the settings.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) => _Flag(languageCode: languageCode);
}

class _Flag extends StatelessWidget {
  const _Flag({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final Widget flag = switch (languageCode) {
      'pl' => const _PolishFlag(),
      'en' => const CustomPaint(painter: _UkFlagPainter()),
      // No flag drawn for this language yet: show its code instead.
      _ => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            languageCode.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    };

    return Container(
      width: 36,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
      ),
      clipBehavior: Clip.antiAlias,
      child: flag,
    );
  }
}

class _PolishFlag extends StatelessWidget {
  const _PolishFlag();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(
          child: ColoredBox(color: Colors.white, child: SizedBox.expand()),
        ),
        Expanded(
          child: ColoredBox(color: Color(0xFFDC143C), child: SizedBox.expand()),
        ),
      ],
    );
  }
}

/// Simplified Union Jack.
class _UkFlagPainter extends CustomPainter {
  const _UkFlagPainter();

  static const _blue = Color(0xFF012169);
  static const _red = Color(0xFFC8102E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = _blue);

    void diagonals(Color color, double width) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = width;
      canvas.drawLine(Offset.zero, Offset(w, h), paint);
      canvas.drawLine(Offset(w, 0), Offset(0, h), paint);
    }

    diagonals(Colors.white, h * 0.2);
    diagonals(_red, h * 0.07);

    void cross(Color color, double width) {
      final paint = Paint()..color = color;
      canvas.drawRect(
        Rect.fromCenter(center: rect.center, width: w, height: width),
        paint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: rect.center, width: width, height: h),
        paint,
      );
    }

    cross(Colors.white, h * 0.33);
    cross(_red, h * 0.2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
