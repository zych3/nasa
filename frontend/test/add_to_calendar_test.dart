import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopito_field_shift/components/rotation/plan_timeline.dart';
import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/rotation_report.dart';
import 'package:hopito_field_shift/widgets/add_to_calendar_button.dart';
import 'package:material_ui/material_ui.dart';

class _FakeCalendar implements CalendarWriter {
  _FakeCalendar({
    this.supported = true,
    this.result = true,
    this.fails = false,
  });

  final bool supported;
  final bool result;
  final bool fails;
  final entries = <CalendarEntry>[];

  @override
  bool get isSupported => supported;

  @override
  Future<bool> add(CalendarEntry entry) async {
    if (fails) throw Exception('no calendar app');
    entries.add(entry);
    return result;
  }
}

Map<String, dynamic> _crop(
  String name, {
  Map<String, dynamic>? sow,
  Map<String, dynamic>? harvest,
  bool sownPreviousYear = false,
}) => {
  'id': name,
  'name': {'en': name, 'pl': name},
  'sow': ?sow,
  'harvest': ?harvest,
  'sownPreviousYear': sownPreviousYear,
};

// Winter rye: sown in autumn 2026 (day 250-280), harvested in summer 2027
// (205-230), then a cover crop sown on days 200-250 of 2027.
RotationPlan _plan({bool dates = true}) => RotationPlan.fromJson({
  'transition': <dynamic>[],
  'cycle': [
    {
      'harvestYear': 2027,
      'crop': dates
          ? _crop(
              'Winter rye',
              sow: {'from': 250, 'to': 280},
              harvest: {'from': 205, 'to': 230},
              sownPreviousYear: true,
            )
          : _crop('Winter rye'),
      'catchCrop': dates
          ? _crop('Phacelia', sow: {'from': 200, 'to': 250})
          : null,
      'harvest': {'value': 0.8, 'level': 'good'},
    },
  ],
  'cycleYears': 1,
  'scores': <dynamic>[],
  'reasons': <dynamic>[],
  'isFeasible': true,
});

Future<void> _show(
  WidgetTester tester,
  CalendarWriter writer, {
  RotationPlan? plan,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: CalendarScope(
        writer: writer,
        child: Scaffold(
          body: SingleChildScrollView(
            child: PlanTimeline(plan: plan ?? _plan()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('every dated task has a button: sowing, harvest, cover crop', (
    tester,
  ) async {
    await _show(tester, _FakeCalendar());

    expect(find.byIcon(Icons.event_available), findsNWidgets(3));
    expect(find.byTooltip('Add to calendar: Sow: Winter rye'), findsOneWidget);
    expect(
      find.byTooltip('Add to calendar: Harvest: Winter rye'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Add to calendar: Sow cover crop: Phacelia'),
      findsOneWidget,
    );
  });

  testWidgets('a winter crop is sown the year before it is harvested', (
    tester,
  ) async {
    final calendar = _FakeCalendar();
    await _show(tester, calendar);

    await tester.tap(find.byTooltip('Add to calendar: Sow: Winter rye'));
    await tester.pump();

    final entry = calendar.entries.single;
    expect(entry.title, 'Sow: Winter rye');
    // Day 250 and 280 of 2026 are 7 September and 7 October, at noon UTC.
    expect(entry.firstDay, DateTime.utc(2026, 9, 7, 12));
    expect(entry.lastDay, DateTime.utc(2026, 10, 7, 12));
    expect(entry.description, contains('approximate'));
  });

  testWidgets('the harvest window is in the harvest year', (tester) async {
    final calendar = _FakeCalendar();
    await _show(tester, calendar);

    await tester.tap(find.byTooltip('Add to calendar: Harvest: Winter rye'));
    await tester.pump();

    final entry = calendar.entries.single;
    expect(entry.title, 'Harvest: Winter rye');
    expect(entry.firstDay, DateTime.utc(2027, 7, 24, 12));
    expect(entry.lastDay, DateTime.utc(2027, 8, 18, 12));
  });

  testWidgets('the cover crop is sown in the harvest year', (tester) async {
    final calendar = _FakeCalendar();
    await _show(tester, calendar);

    await tester.tap(
      find.byTooltip('Add to calendar: Sow cover crop: Phacelia'),
    );
    await tester.pump();

    final entry = calendar.entries.single;
    expect(entry.title, 'Sow cover crop: Phacelia');
    expect(entry.firstDay, DateTime.utc(2027, 7, 19, 12));
    expect(entry.lastDay, DateTime.utc(2027, 9, 7, 12));
  });

  testWidgets('a calendar that cannot be opened is reported', (tester) async {
    await _show(tester, _FakeCalendar(result: false));

    await tester.tap(find.byTooltip('Add to calendar: Sow: Winter rye'));
    await tester.pump();

    expect(
      find.text('Could not open the calendar on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('an error from the platform is reported too', (tester) async {
    await _show(tester, _FakeCalendar(fails: true));

    await tester.tap(find.byTooltip('Add to calendar: Sow: Winter rye'));
    await tester.pump();

    expect(
      find.text('Could not open the calendar on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('without a device calendar the dates stay but no buttons', (
    tester,
  ) async {
    await _show(tester, _FakeCalendar(supported: false));

    expect(find.byIcon(Icons.event_available), findsNothing);
    expect(find.textContaining('Sow: September'), findsOneWidget);
    expect(find.textContaining('Harvest time: July'), findsOneWidget);
  });

  testWidgets('a crop without dates has nothing to add', (tester) async {
    await _show(tester, _FakeCalendar(), plan: _plan(dates: false));

    expect(find.byIcon(Icons.event_available), findsNothing);
  });

  group('DeviceCalendarWriter', () {
    test('is supported on Android and iOS', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          DeviceCalendarWriter.instance.isSupported,
          isTrue,
          reason: '$platform',
        );
      }
    });

    test('is not supported on desktop', () {
      for (final platform in [
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          DeviceCalendarWriter.instance.isSupported,
          isFalse,
          reason: '$platform',
        );
      }
    });
  });
}
