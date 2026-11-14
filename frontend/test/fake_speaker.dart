import 'package:flutter/foundation.dart';
import 'package:hopito_field_shift/widgets/read_aloud_button.dart';

/// [Speaker] that records what it was asked to read.
class FakeSpeaker implements Speaker {
  final _speaking = ValueNotifier<Object?>(null);
  final spoken = <(String, String)>[];
  int stops = 0;
  bool fail = false;

  @override
  ValueListenable<Object?> get speaking => _speaking;

  @override
  Future<void> speak(
    String text, {
    required String languageTag,
    required Object owner,
  }) async {
    if (fail) throw Exception('no engine');
    spoken.add((text, languageTag));
    _speaking.value = owner;
  }

  @override
  Future<void> stop() async {
    stops++;
    _speaking.value = null;
  }

  /// The engine finished reading by itself.
  void finish() => _speaking.value = null;
}
