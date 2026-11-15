import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Small bar chart (e.g. rain per day). Hidden from screen readers: the text
/// next to it says the same.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 48,
  });

  /// `null` = no value that day (drawn as a gap).
  final List<double?> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.outline;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _BarsPainter(values, color, base)),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.color, this.base);

  final List<double?> values;
  final Color color;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.whereType<double>().fold<double>(0, math.max);
    final slot = size.width / values.length;
    final bar = Paint()..color = color;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = base
        ..strokeWidth = 1,
    );
    if (max <= 0) return;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null || v <= 0) continue;
      final h = math.max(2.0, (v / max) * (size.height - 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * slot + slot * 0.15, size.height - h, slot * 0.7, h),
          const Radius.circular(2),
        ),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values || old.color != color;
}

/// Small line chart of a series against its normal (dashed). Hidden from
/// screen readers: the text next to it says the same.
class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.values,
    required this.color,
    this.normals = const [],
    this.height = 56,
  });

  final List<double?> values;

  /// Same length as [values] (or empty); drawn dashed.
  final List<double?> normals;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(values, normals, color, muted),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.normals, this.color, this.muted);

  final List<double?> values;
  final List<double?> normals;
  final Color color;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...values, ...normals].whereType<double>().toList();
    if (all.length < 2) return;
    var lo = all.reduce(math.min);
    var hi = all.reduce(math.max);
    if (hi - lo < 1e-6) {
      hi += 0.5;
      lo -= 0.5;
    }
    final n = math.max(values.length, normals.length);
    Offset at(int i, double v) => Offset(
      n == 1 ? size.width / 2 : i * size.width / (n - 1),
      size.height - 3 - (v - lo) / (hi - lo) * (size.height - 6),
    );

    Path path(List<double?> series) {
      final p = Path();
      var started = false;
      for (var i = 0; i < series.length; i++) {
        final v = series[i];
        if (v == null) {
          started = false;
          continue;
        }
        final o = at(i, v);
        started ? p.lineTo(o.dx, o.dy) : p.moveTo(o.dx, o.dy);
        started = true;
      }
      return p;
    }

    // Normal: dashed by drawing short pieces of its path.
    final normalPaint = Paint()
      ..color = muted
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final metric in path(normals).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), normalPaint);
      }
    }
    canvas.drawPath(
      path(values),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.normals != normals || old.color != color;
}
