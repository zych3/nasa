import 'package:intl/intl.dart';

import '../models/climate_trends.dart';
import 'app_localizations.dart';

/// Translates the codes of `GET /api/parcels/climate-trends` into text in the
/// current language.
///
/// The backend never sends display sentences. Unknown codes return null, so
/// the UI shows nothing rather than a raw code. When the backend adds a code,
/// add it here and to both ARB files.

/// What changed, as a short headline: the indicator and its direction in
/// one phrase ("More hot days"), so the direction is always a word.
String? climateTrendHeadline(AppLocalizations l10n, ClimateTrend trend) =>
    switch ((trend.id, trend.direction)) {
      ('frost_free_days', 'up') => l10n.climateFrostFreeUp,
      ('frost_free_days', 'down') => l10n.climateFrostFreeDown,
      ('last_spring_frost', 'up') => l10n.climateLastSpringFrostUp,
      ('last_spring_frost', 'down') => l10n.climateLastSpringFrostDown,
      ('first_autumn_frost', 'up') => l10n.climateFirstAutumnFrostUp,
      ('first_autumn_frost', 'down') => l10n.climateFirstAutumnFrostDown,
      ('hot_days', 'up') => l10n.climateHotDaysUp,
      ('hot_days', 'down') => l10n.climateHotDaysDown,
      ('max_temperature', 'up') => l10n.climateMaxTemperatureUp,
      ('max_temperature', 'down') => l10n.climateMaxTemperatureDown,
      ('growing_degree_days', 'up') => l10n.climateGrowingWarmthUp,
      ('growing_degree_days', 'down') => l10n.climateGrowingWarmthDown,
      ('longest_dry_spell', 'up') => l10n.climateDrySpellUp,
      ('longest_dry_spell', 'down') => l10n.climateDrySpellDown,
      ('season_precipitation', 'up') => l10n.climateSeasonRainUp,
      ('season_precipitation', 'down') => l10n.climateSeasonRainDown,
      ('water_balance', 'up') => l10n.climateWaterBalanceUp,
      ('water_balance', 'down') => l10n.climateWaterBalanceDown,
      ('heavy_rain_days', 'up') => l10n.climateHeavyRainUp,
      ('heavy_rain_days', 'down') => l10n.climateHeavyRainDown,
      _ => null,
    };

/// A long-term option to consider (`adviceCodes`).
String? climateAdviceText(AppLocalizations l10n, String code) => switch (code) {
  'heat_tolerant_varieties' => l10n.climateAdviceHeatTolerantVarieties,
  'keep_soil_covered' => l10n.climateAdviceKeepSoilCovered,
  'drought_crops_on_light_soil' => l10n.climateAdviceDroughtCropsOnLightSoil,
  'use_longer_season' => l10n.climateAdviceUseLongerSeason,
  'do_not_sow_earlier' => l10n.climateAdviceDoNotSowEarlier,
  'check_warm_season_crops' => l10n.climateAdviceCheckWarmSeasonCrops,
  'protect_from_erosion' => l10n.climateAdviceProtectFromErosion,
  'work_across_slope' => l10n.climateAdviceWorkAcrossSlope,
  _ => null,
};

/// A caution about the data (`noteCodes`).
String? climateNoteText(AppLocalizations l10n, String code, int gridKm) =>
    switch (code) {
      'regional_climate_grid' => l10n.climateNoteRegional('$gridKm'),
      'frost_measured_in_air' => l10n.climateNoteAirFrost,
      'evaporation_estimated_from_temperature' => l10n.climateNoteEvaporation,
      _ => null,
    };

/// A mean of [trend] with its unit ("13 days", "24 April", "34.5 °C"); null
/// for a unit this version does not know.
String? climateValueText(
  AppLocalizations l10n,
  String locale,
  ClimateTrend trend,
  double value,
) {
  String number(int decimals) =>
      (NumberFormat.decimalPattern(locale)
            ..minimumFractionDigits = decimals
            ..maximumFractionDigits = decimals)
          .format(value);

  return switch (trend.unit) {
    'days' => l10n.climateValueDays(value.round()),
    // A day of the year as a date; 2001 is not a leap year.
    'day_of_year' => DateFormat.MMMMd(
      locale,
    ).format(DateTime.utc(2001).add(Duration(days: value.round() - 1))),
    'celsius' => l10n.climateValueCelsius(number(1)),
    'degree_days' => l10n.climateValueHeatUnits(number(0)),
    'millimetres' => l10n.climateValueMillimetres(number(0)),
    _ => null,
  };
}

/// "On average 7 days in 1981–1995, and 13 days in 2011–2025." Only means of
/// past years: nothing is projected forward.
String? climateFactText(
  AppLocalizations l10n,
  String locale,
  ClimateTrend trend,
) {
  final early = climateValueText(l10n, locale, trend, trend.earlyMean);
  final recent = climateValueText(l10n, locale, trend, trend.recentMean);
  if (early == null || recent == null) return null;
  return l10n.climateFact(
    early,
    '${trend.earlyFrom}',
    '${trend.earlyTo}',
    recent,
    '${trend.recentFrom}',
    '${trend.recentTo}',
  );
}

/// Trends this version can put into words (known indicator and unit).
List<ClimateTrend> climateTrendsToShow(
  AppLocalizations l10n,
  String locale,
  ClimateTrends trends,
) => [
  if (trends.hasTrends)
    for (final t in trends.trends)
      if (climateTrendHeadline(l10n, t) != null &&
          climateFactText(l10n, locale, t) != null)
        t,
];

/// Cautions and the source line under the trends, in the order shown.
List<String> climateFootnotes(AppLocalizations l10n, ClimateTrends trends) => [
  l10n.climateNotForecast,
  for (final code in trends.noteCodes)
    ?climateNoteText(l10n, code, trends.gridKm),
  l10n.climateSource(trends.source, '${trends.fromYear}', '${trends.toYear}'),
];

/// Everything the climate section shows, in the order it shows it; empty
/// when the section shows nothing.
List<String> climateReadingSentences(
  AppLocalizations l10n,
  String locale,
  ClimateTrends? trends,
) {
  if (trends == null) return const [];
  final shown = climateTrendsToShow(l10n, locale, trends);
  if (shown.isEmpty && !trends.hasNoClearTrends) return const [];

  return [
    l10n.climateSectionTitle,
    if (shown.isEmpty)
      l10n.climateNoClearTrends('${trends.fromYear}', '${trends.toYear}'),
    for (final t in shown) ...[
      climateTrendHeadline(l10n, t)!,
      climateFactText(l10n, locale, t)!,
      if (t.adviceCodes.any((c) => climateAdviceText(l10n, c) != null))
        l10n.climateAdviceTitle,
      for (final code in t.adviceCodes) ?climateAdviceText(l10n, code),
    ],
    ...climateFootnotes(l10n, trends),
  ];
}
