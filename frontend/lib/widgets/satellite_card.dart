import 'package:forui/forui.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/satellite_data.dart';
import 'mini_charts.dart';

/// "From NASA satellites – recent": rain (GPM IMERG), soil (SMAP), plant
/// greenness (MODIS NDVI), ground temperature and evapotranspiration
/// (MODIS) for the field. Every value says in words how it compares with the
/// same time of year, with its date, source and how big an area it covers.
/// Parts still loading are left out (the loading card shows them).
class SatelliteCard extends StatelessWidget {
  const SatelliteCard({
    super.key,
    required this.data,
    this.parts = SatellitePart.values,
    this.title,
    this.subtitle,
  });

  /// Loaded parts (models from `FieldConditionsController.parseSatellite`).
  final Map<SatellitePart, Object> data;

  /// Which parts to show, in this order.
  final List<SatellitePart> parts;

  /// Defaults to "From NASA satellites – recent".
  final String? title;
  final String? subtitle;

  /// Warnings for the "Watch out" box, from the satellite parts. Pure.
  static List<String> warnings(
    AppLocalizations l10n,
    Map<SatellitePart, Object> data,
  ) {
    final soil = data[SatellitePart.soil] as SoilData?;
    final rain = data[SatellitePart.rain] as RainData?;
    final veg = data[SatellitePart.vegetation] as VegetationData?;
    final lst = data[SatellitePart.surfaceTemperature] as SurfaceTempData?;
    return [
      if (soil?.level == SatelliteLevel.below) l10n.satWarnSoilDry,
      if (soil?.frozen ?? false) l10n.satWarnFrozen,
      if (lst?.groundFrost ?? false) l10n.satWarnGroundFrost,
      if ((rain?.heavyRainDays ?? 0) >= 2)
        l10n.satWarnHeavyRain(rain!.heavyRainDays!),
      if ((rain?.dryDaysInRow ?? 0) >= 10)
        l10n.satWarnDrySpell(rain!.dryDaysInRow!),
      if (veg?.level == SatelliteLevel.below) l10n.satWarnNdviLow,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.theme;
    final colors = theme.colors;
    final rows = <Widget>[
      for (final part in parts)
        if (data[part] case final model? when !_notConfigured(model))
          switch (model) {
            RainData m => _RainRow(m),
            SoilData m => _SoilRow(m),
            VegetationData m => _VegetationRow(m),
            SurfaceTempData m => _SurfaceTempRow(m),
            EvapotranspirationData m => _EtRow(m),
            _ => const SizedBox.shrink(),
          },
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return FCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title ?? l10n.satTitle,
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle ?? l10n.satSubtitle,
              style: theme.typography.body.sm.copyWith(
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const FDivider(),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

String _n(AppLocalizations l10n, double v, int decimals) =>
    NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: decimals,
    ).format(v);

String _day(AppLocalizations l10n, DateTime d) =>
    DateFormat.yMMMd(l10n.localeName).format(d);

/// A part the server cannot measure (it has no NASA Earthdata key) is left out
/// of the card: the user cannot do anything about it, and a technical note
/// about the server would only confuse.
bool _notConfigured(Object model) => switch (model) {
  RainData m => m.status == SatelliteStatus.notConfigured,
  SoilData m => m.status == SatelliteStatus.notConfigured,
  VegetationData m => m.status == SatelliteStatus.notConfigured,
  SurfaceTempData m => m.status == SatelliteStatus.notConfigured,
  EvapotranspirationData m => m.status == SatelliteStatus.notConfigured,
  _ => false,
};

/// Words for a part that has no value. (`notConfigured` parts are not shown at
/// all, see [_notConfigured].)
String? _statusText(AppLocalizations l10n, SatelliteStatus status) =>
    switch (status) {
      SatelliteStatus.ok || SatelliteStatus.notConfigured => null,
      SatelliteStatus.noData => l10n.satNoData,
      SatelliteStatus.unavailable => l10n.satUnavailable,
    };

/// One part: icon tile, title, main sentence, more lines, chart, note.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.main,
    this.warning = false,
    this.lines = const [],
    this.chart,
    this.note,
  });

  final IconData icon;
  final String title;
  final String main;
  final bool warning;
  final List<String> lines;
  final Widget? chart;

  /// Date, source, area covered (small, muted).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final type = theme.typography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: colors.foreground),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: type.body.sm.copyWith(color: colors.mutedForeground),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (warning) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          FLucideIcons.triangleAlert,
                          size: 18,
                          color: colors.error,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        main,
                        style: type.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: type.body.sm.copyWith(color: colors.foreground),
                  ),
                ],
                if (chart case final c?) ...[const SizedBox(height: 10), c],
                if (note case final n?) ...[
                  const SizedBox(height: 6),
                  Text(
                    n,
                    style: type.body.xs.copyWith(color: colors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _note(
  AppLocalizations l10n,
  DateTime? date,
  String source,
  String area,
) => [
  if (date != null) l10n.satDate(_day(l10n, date)),
  area,
  if (source.isNotEmpty) l10n.overlaysSource(source),
].join(' · ');

class _RainRow extends StatelessWidget {
  const _RainRow(this.rain);

  final RainData rain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.theme.colors;
    final status = _statusText(l10n, rain.status);
    final week = rain.last7Mm;
    final month = rain.last30Mm;
    return _Row(
      icon: FLucideIcons.cloudRain,
      title: l10n.satRainTitle,
      main:
          status ??
          (week != null && month != null
              ? l10n.satRainValue(_n(l10n, week, 1), _n(l10n, month, 1))
              : l10n.satNoData),
      warning: (rain.heavyRainDays ?? 0) >= 2,
      lines: [
        if (rain.last1Mm case final day?) l10n.satRainLastDay(_n(l10n, day, 1)),
        if ((rain.dryDaysInRow ?? 0) >= 2) l10n.satRainDry(rain.dryDaysInRow!),
        if ((rain.heavyRainDays ?? 0) > 0)
          l10n.satRainHeavy(rain.heavyRainDays!),
      ],
      chart: rain.days.length > 2
          ? MiniBarChart(
              values: [for (final d in rain.days) d.mm],
              color: colors.primary,
            )
          : null,
      note: status != null
          ? null
          : _note(l10n, rain.latestDate, rain.source, l10n.satAreaRain),
    );
  }
}

class _SoilRow extends StatelessWidget {
  const _SoilRow(this.soil);

  final SoilData soil;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.theme.colors;
    final status = _statusText(l10n, soil.status);
    final wet = soil.rootzoneWetness;
    final normal = soil.normalWetness;
    return _Row(
      icon: FLucideIcons.droplets,
      title: l10n.satSoilTitle,
      main:
          status ??
          switch (soil.level) {
            SatelliteLevel.below => l10n.satSoilBelow,
            SatelliteLevel.above => l10n.satSoilAbove,
            SatelliteLevel.normal => l10n.satSoilNormal,
            null => wet == null ? l10n.satNoData : l10n.satSoilScale,
          },
      warning: soil.level == SatelliteLevel.below || soil.frozen,
      lines: [
        if (wet != null && normal != null)
          l10n.satSoilValueNormal(
            _n(l10n, wet, 2),
            _n(l10n, normal, 2),
            soil.normalYears,
          )
        else if (wet != null)
          l10n.satSoilValue(_n(l10n, wet, 2)),
        if (soil.soilTempC case final t?) l10n.satSoilTemp(_n(l10n, t, 1)),
        if (soil.frozen) l10n.satWarnFrozen,
        if ((soil.snowDepthCm ?? 0) > 0)
          l10n.satSnow(_n(l10n, soil.snowDepthCm!, 0)),
      ],
      chart: soil.days.length > 2
          ? MiniLineChart(
              values: [for (final d in soil.days) d.wetness],
              normals: normal == null
                  ? const []
                  : [for (final _ in soil.days) normal],
              color: colors.primary,
            )
          : null,
      note: status != null
          ? null
          : _note(l10n, soil.time, soil.source, l10n.satAreaSoil),
    );
  }
}

class _VegetationRow extends StatelessWidget {
  const _VegetationRow(this.veg);

  final VegetationData veg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.theme.colors;
    final status = _statusText(l10n, veg.status);
    final latest = veg.latest;
    return _Row(
      icon: FLucideIcons.leaf,
      title: l10n.satNdviTitle,
      main:
          status ??
          switch (veg.level) {
            SatelliteLevel.below => l10n.satNdviBelow,
            SatelliteLevel.above => l10n.satNdviAbove,
            SatelliteLevel.normal => l10n.satNdviNormal,
            null => l10n.satNdviScale,
          },
      warning: veg.level == SatelliteLevel.below,
      lines: [
        if (latest?.value case final v?)
          latest!.normal == null
              ? l10n.satNdviValue(_n(l10n, v, 2))
              : l10n.satNdviValueNormal(
                  _n(l10n, v, 2),
                  _n(l10n, latest.normal!, 2),
                ),
        if (veg.reliability == 'cloudy' || veg.reliability == 'snow')
          l10n.satNdviCloudy,
        if (status == null) l10n.satNdviHelp,
      ],
      chart: veg.season.length > 2
          ? MiniLineChart(
              values: [for (final p in veg.season) p.value],
              normals: [for (final p in veg.season) p.normal],
              color: colors.primary,
            )
          : null,
      note: status != null
          ? null
          : _note(l10n, latest?.date, veg.source, l10n.satAreaNdvi),
    );
  }
}

class _SurfaceTempRow extends StatelessWidget {
  const _SurfaceTempRow(this.lst);

  final SurfaceTempData lst;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _statusText(l10n, lst.status);
    final day = lst.dayC;
    final night = lst.nightC;
    return _Row(
      icon: FLucideIcons.thermometer,
      title: l10n.satLstTitle,
      main:
          status ??
          (day != null && night != null
              ? l10n.satLstValue(_n(l10n, day, 0), _n(l10n, night, 0))
              : day != null
              ? l10n.satLstDay(_n(l10n, day, 0))
              : night != null
              ? l10n.satLstNight(_n(l10n, night, 0))
              : l10n.satNoData),
      warning: lst.groundFrost,
      lines: [
        if (lst.normalDayC != null && lst.normalNightC != null)
          l10n.satLstNormal(
            _n(l10n, lst.normalDayC!, 0),
            _n(l10n, lst.normalNightC!, 0),
          ),
        if (lst.groundFrost) l10n.satWarnGroundFrost,
      ],
      note: status != null
          ? null
          : _note(l10n, lst.date, lst.source, l10n.satAreaLst),
    );
  }
}

class _EtRow extends StatelessWidget {
  const _EtRow(this.et);

  final EvapotranspirationData et;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _statusText(l10n, et.status);
    final latest = et.latest;
    return _Row(
      icon: FLucideIcons.sprout,
      title: l10n.satEtTitle,
      main:
          status ??
          switch (et.level) {
            SatelliteLevel.below => l10n.satEtBelow,
            SatelliteLevel.above => l10n.satEtAbove,
            SatelliteLevel.normal => l10n.satEtNormal,
            null =>
              latest?.value == null
                  ? l10n.satNoData
                  : l10n.satEtValue(_n(l10n, latest!.value!, 1)),
          },
      lines: [
        if (et.level != null && latest?.value != null && latest?.normal != null)
          l10n.satEtValueNormal(
            _n(l10n, latest!.value!, 1),
            _n(l10n, latest.normal!, 1),
          ),
      ],
      note: status != null
          ? null
          : _note(l10n, latest?.date, et.source, l10n.satAreaEt),
    );
  }
}
