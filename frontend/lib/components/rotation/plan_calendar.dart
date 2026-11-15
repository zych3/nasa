import '../../l10n/app_localizations.dart';
import '../../models/rotation_report.dart';
import '../../widgets/add_to_calendar_button.dart';

/// Day [dayOfYear] (1..366) of [year], at 12:00 UTC (see [CalendarEntry]).
DateTime _day(int year, int dayOfYear) =>
    DateTime.utc(year, 1, 1, 12).add(Duration(days: dayOfYear - 1));

CalendarEntry? _entry(
  AppLocalizations l10n,
  String title,
  DayRange? window,
  int year,
) => window == null
    ? null
    : CalendarEntry(
        title: title,
        description: l10n.calendarNote,
        firstDay: _day(year, window.from),
        lastDay: _day(year, window.to),
      );

/// The sowing window of the main crop of [season] (the year before harvest
/// for winter crops), or null when the dates are unknown.
CalendarEntry? seasonSowEntry(
  AppLocalizations l10n,
  String language,
  PlanSeason season,
) => _entry(
  l10n,
  l10n.calendarSowTitle(season.crop.nameFor(language)),
  season.crop.sow,
  season.year - (season.crop.sownPreviousYear ? 1 : 0),
);

CalendarEntry? seasonHarvestEntry(
  AppLocalizations l10n,
  String language,
  PlanSeason season,
) => _entry(
  l10n,
  l10n.calendarHarvestTitle(season.crop.nameFor(language)),
  season.crop.harvest,
  season.year,
);

/// The cover crop is sown after the main harvest, in the harvest year.
CalendarEntry? catchSowEntry(
  AppLocalizations l10n,
  String language,
  PlanSeason season,
) {
  final catchCrop = season.catchCrop;
  if (catchCrop == null) return null;
  return _entry(
    l10n,
    l10n.calendarCoverTitle(catchCrop.nameFor(language)),
    catchCrop.sow,
    season.year,
  );
}
