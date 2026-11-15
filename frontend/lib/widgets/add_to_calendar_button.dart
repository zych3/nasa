import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

/// One all-day event for the calendar: a task that has a window of days.
///
/// [firstDay] and [lastDay] are the first and last day of the window, both at
/// 12:00 UTC. Android reads all-day times as UTC and iOS as local days, and
/// noon UTC is the same calendar day in every time zone from UTC−12 to UTC+11,
/// so the event lands on the right days on both.
class CalendarEntry {
  const CalendarEntry({
    required this.title,
    required this.description,
    required this.firstDay,
    required this.lastDay,
  });

  final String title;
  final String description;
  final DateTime firstDay;
  final DateTime lastDay;
}

/// Puts events in the device calendar. The app uses [DeviceCalendarWriter];
/// tests put a fake one in a [CalendarScope].
abstract class CalendarWriter {
  /// False where there is no device calendar to write to (web, desktop): the
  /// buttons are then not shown at all.
  bool get isSupported;

  /// Opens the system "add event" screen filled in with [entry], where the
  /// user picks the calendar and confirms. False when it could not be opened.
  Future<bool> add(CalendarEntry entry);
}

/// [CalendarWriter] using the system add-event screen (`add_2_calendar`): no
/// calendar permission is needed, the user stays in control of what is saved.
class DeviceCalendarWriter implements CalendarWriter {
  const DeviceCalendarWriter._();

  static const DeviceCalendarWriter instance = DeviceCalendarWriter._();

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> add(CalendarEntry entry) => cal.Add2Calendar.addEvent2Cal(
    cal.Event(
      title: entry.title,
      description: entry.description,
      startDate: entry.firstDay,
      endDate: entry.lastDay,
      allDay: true,
    ),
  );
}

/// Gives the widgets below a [CalendarWriter] (tests use a fake one). Without
/// it, [DeviceCalendarWriter.instance] is used.
class CalendarScope extends InheritedWidget {
  const CalendarScope({super.key, required this.writer, required super.child});

  final CalendarWriter writer;

  static CalendarWriter of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CalendarScope>()?.writer ??
      DeviceCalendarWriter.instance;

  @override
  bool updateShouldNotify(CalendarScope oldWidget) =>
      writer != oldWidget.writer;
}

/// "Add to calendar" button for one [entry]. Shows nothing where the device
/// has no calendar to write to.
class AddToCalendarButton extends StatelessWidget {
  const AddToCalendarButton({super.key, required this.entry});

  final CalendarEntry entry;

  Future<void> _add(BuildContext context, CalendarWriter writer) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).calendarFailed;

    var opened = false;
    try {
      opened = await writer.add(entry);
    } catch (_) {
      // No calendar app, or the platform refused: said below.
    }
    if (!opened) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final writer = CalendarScope.of(context);
    if (!writer.isSupported) return const SizedBox.shrink();

    return IconButton(
      iconSize: 28,
      tooltip: AppLocalizations.of(context).calendarAddFor(entry.title),
      icon: const Icon(Icons.event_available),
      onPressed: () => _add(context, writer),
    );
  }
}
