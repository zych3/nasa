import 'app_localizations.dart';

/// Translates a note code from the backend (`noteCode`, `priceNoteCode`,
/// `productionNoteCode`) into text in the current language.
///
/// The backend never sends display sentences. Unknown codes return null, so
/// the UI shows nothing rather than a raw code. When the backend adds a code,
/// add it here and to both ARB files.
String? cropNoteText(AppLocalizations l10n, String? code) => switch (code) {
  'one_price_all_wheat' => l10n.noteOnePriceAllWheat,
  'one_price_all_rye' => l10n.noteOnePriceAllRye,
  'one_price_all_barley' => l10n.noteOnePriceAllBarley,
  'grain_maize_price' => l10n.noteGrainMaizePrice,
  'yearly_only' => l10n.noteYearlyOnly,
  'grain_maize_only' => l10n.noteGrainMaizeOnly,
  'all_sweet_lupins' => l10n.noteAllSweetLupins,
  'no_eurostat_figure' => l10n.noteNoEurostatFigure,
  _ => null,
};
