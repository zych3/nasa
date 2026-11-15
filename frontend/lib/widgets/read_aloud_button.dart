import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// Reads text aloud. One for the whole app ([TtsSpeaker.instance]); tests
/// put a fake one in a [SpeakerScope].
abstract class Speaker {
  /// Who is speaking now (the `owner` given to [speak]); `null` when silent.
  ValueListenable<Object?> get speaking;

  /// Reads [text] in [languageTag] (e.g. "pl-PL"), stopping anything that is
  /// being read. Throws when the device cannot read aloud.
  Future<void> speak(
    String text, {
    required String languageTag,
    required Object owner,
  });

  Future<void> stop();
}

/// [Speaker] using the device's text-to-speech (`flutter_tts`).
class TtsSpeaker implements Speaker {
  TtsSpeaker._();

  static final TtsSpeaker instance = TtsSpeaker._();

  final _speaking = ValueNotifier<Object?>(null);

  // Created on first use, so screens that never read aloud (and tests) do
  // not start the speech engine.
  late final FlutterTts _tts = FlutterTts()
    ..setCompletionHandler(_done)
    ..setCancelHandler(_done)
    ..setErrorHandler((_) => _done());

  void _done() => _speaking.value = null;

  @override
  ValueListenable<Object?> get speaking => _speaking;

  @override
  Future<void> speak(
    String text, {
    required String languageTag,
    required Object owner,
  }) async {
    await _tts.stop();
    _speaking.value = owner;
    try {
      await _tts.setLanguage(languageTag);
      await _tts.speak(text);
    } catch (_) {
      _done();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _done();
    await _tts.stop();
  }
}

/// Gives the widgets below a [Speaker] (tests use a fake one). Without it,
/// [TtsSpeaker.instance] is used.
class SpeakerScope extends InheritedWidget {
  const SpeakerScope({super.key, required this.speaker, required super.child});

  final Speaker speaker;

  static Speaker of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpeakerScope>()?.speaker ??
      TtsSpeaker.instance;

  @override
  bool updateShouldNotify(SpeakerScope oldWidget) =>
      speaker != oldWidget.speaker;
}

/// "Read aloud" button (AGENTS.md: every screen has one). Reads [text] in the
/// app's language; while reading it turns into "Stop".
class ReadAloudButton extends StatefulWidget {
  const ReadAloudButton({super.key, required this.text});

  /// What to read, built at the moment of the tap (what is on screen now).
  final String Function() text;

  @override
  State<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends State<ReadAloudButton> {
  Speaker? _speaker;

  bool get _isSpeaking => _speaker?.speaking.value == this;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final speaker = SpeakerScope.of(context);
    if (speaker != _speaker) {
      _speaker?.speaking.removeListener(_changed);
      _speaker = speaker..speaking.addListener(_changed);
    }
  }

  @override
  void dispose() {
    final speaker = _speaker;
    speaker?.speaking.removeListener(_changed);
    // Leaving the screen stops our reading.
    if (speaker != null && speaker.speaking.value == this) speaker.stop();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// "pl" → "pl-PL"; voices are looked up by region.
  static String _languageTag(Locale locale) => switch (locale.languageCode) {
    'pl' => 'pl-PL',
    'en' => 'en-GB',
    final code => code,
  };

  Future<void> _toggle() async {
    final speaker = _speaker!;
    if (_isSpeaking) {
      await speaker.stop();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).readAloudUnavailable;
    try {
      await speaker.speak(
        widget.text(),
        languageTag: _languageTag(Localizations.localeOf(context)),
        owner: this,
      );
    } catch (_) {
      // No speech engine (e.g. Linux desktop) or no voice for the language.
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final speaking = _isSpeaking;
    return IconButton.filledTonal(
      style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
      tooltip: speaking ? l10n.readAloudStop : l10n.readAloud,
      isSelected: speaking,
      onPressed: _toggle,
      icon: const Icon(Icons.volume_up, size: 28),
      selectedIcon: const Icon(Icons.stop, size: 28),
    );
  }
}

/// Joins separate sentences for reading aloud, adding a full stop where a
/// sentence has none, so the voice pauses between them. Each part is a whole
/// sentence from the ARB files; nothing is assembled from word fragments.
String sentencesForReading(Iterable<String?> parts) => [
  for (final part in parts)
    if (part != null && part.trim().isNotEmpty)
      RegExp(r'[.!?…]$').hasMatch(part.trim())
          ? part.trim()
          : '${part.trim()}.',
].join(' ');
