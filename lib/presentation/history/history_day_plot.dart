import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/history/day_detail.dart';
import 'history_plot_colours.dart';

export 'history_plot_colours.dart';

/// Draws a reading through the day: for each hour with data a rounded bar from its lowest to its
/// highest value with a dot at its average, a smooth line through the averages of neighbouring
/// hours, the normal range as a band, value labels at the left, and under the plot a strip of the
/// hours with data, missing and not begun. Hours run 0–24 across, [low]–[high] up.
class HistoryDayPlot extends CustomPainter {
  const HistoryDayPlot({
    required this.hours,
    required this.clockHours,
    required this.coverage,
    required this.low,
    required this.high,
    required this.normal,
    required this.outside,
    required this.labels,
    required this.gutter,
    required this.picked,
    required this.colours,
    required this.labelStyle,
    required this.textScaler,
  });

  /// The plot's height, and the gap and height of the strip under it.
  static const plotHeight = 88.0;
  static const stripGap = 8.0;
  static const stripHeight = 6.0;
  static const height = plotHeight + stripGap + stripHeight;

  final Map<int, HourFigures> hours;

  /// The day's wall-clock hours in order; the line joins an hour to the next one only.
  final List<int> clockHours;
  final List<(int, HourCoverage)> coverage;
  final double low;
  final double high;

  /// The normal range (low, high); none when null.
  final (double, double)? normal;

  /// The hours whose average, as shown, is outside the normal range: drawn as a hollow ring.
  final Set<int> outside;

  /// Values written at the left, as (value, text), highest first.
  final List<(double, String)> labels;

  /// The width at the left kept for [labels].
  final double gutter;
  final int? picked;
  final HistoryPlotColours colours;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  /// Where the hour [h] starts in a plot of [width] (after the gutter).
  double xOf(double h, double width) => gutter + (width - gutter) * h / 24;

  double _y(double value) => plotHeight * (high - value) / (high - low);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(gutter, 0, size.width, plotHeight);
    final frame = RRect.fromRectAndRadius(plot, const Radius.circular(8));
    canvas.drawRRect(frame, Paint()..color = colours.frame);

    canvas
      ..save()
      ..clipRRect(frame);
    _band(canvas, plot);
    for (final h in const [6, 12, 18]) {
      final x = xOf(h.toDouble(), size.width);
      _dashed(canvas, Offset(x, 0), Offset(x, plotHeight), colours.grid);
    }
    if (picked case final h?) {
      final rect = Rect.fromLTRB(
        xOf(h.toDouble(), size.width),
        0,
        xOf(h + 1.0, size.width),
        plotHeight,
      );
      canvas.drawRect(rect, Paint()..color = colours.picked);
    }
    _ranges(canvas, size.width);
    _line(canvas, size.width);
    _dots(canvas, size.width);
    canvas.restore();

    _labels(canvas);
    _strip(canvas, size.width);
  }

  void _band(Canvas canvas, Rect plot) {
    final range = normal;
    if (range == null) return;
    final (from, to) = range;
    if (to <= low || from >= high) return;
    final top = _y(to < high ? to : high);
    final bottom = _y(from > low ? from : low);
    canvas.drawRect(
      Rect.fromLTRB(plot.left, top, plot.right, bottom),
      Paint()..color = colours.band,
    );
    for (final edge in [to, from]) {
      if (edge > low && edge < high) {
        _dashed(
          canvas,
          Offset(plot.left, _y(edge)),
          Offset(plot.right, _y(edge)),
          colours.bandEdge,
        );
      }
    }
  }

  /// Bar width: half an hour's width, kept between 3 and 9 px.
  double _barWidth(double width) => ((width - gutter) / 24 * 0.5).clamp(3.0, 9.0);

  void _ranges(Canvas canvas, double width) {
    final w = _barWidth(width);
    final paint = Paint()..color = colours.range;
    for (final MapEntry(key: h, value: f) in hours.entries) {
      final cx = xOf(h + 0.5, width);
      var top = _y(f.max);
      var bottom = _y(f.min);
      if (bottom - top < w) {
        // A steady hour is a round pill, never a hairline.
        final mid = (top + bottom) / 2;
        top = mid - w / 2;
        bottom = mid + w / 2;
      }
      canvas.drawRRect(
        RRect.fromLTRBR(cx - w / 2, top, cx + w / 2, bottom, Radius.circular(w / 2)),
        paint,
      );
    }
  }

  /// A smooth line through the averages of neighbouring hours: each step leaves and arrives level,
  /// so it never overshoots the values it joins.
  void _line(Canvas canvas, double width) {
    final path = Path();
    for (var i = 0; i + 1 < clockHours.length; i++) {
      final (a, b) = (hours[clockHours[i]], hours[clockHours[i + 1]]);
      if (a == null || b == null) continue;
      final p0 = Offset(xOf(clockHours[i] + 0.5, width), _y(a.avg));
      final p1 = Offset(xOf(clockHours[i + 1] + 0.5, width), _y(b.avg));
      final mid = (p0.dx + p1.dx) / 2;
      path
        ..moveTo(p0.dx, p0.dy)
        ..cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colours.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _dots(Canvas canvas, double width) {
    for (final MapEntry(key: h, value: f) in hours.entries) {
      final centre = Offset(xOf(h + 0.5, width), _y(f.avg));
      final radius = h == picked ? 4.5 : 3.0;
      canvas.drawCircle(centre, radius + 1.5, Paint()..color = colours.ring);
      if (outside.contains(h)) {
        // Outside the normal range: a hollow ring, so its shape says so as well as its colour.
        canvas.drawCircle(
          centre,
          radius,
          Paint()
            ..color = colours.outside
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(centre, radius, Paint()..color = colours.line);
      }
    }
  }

  /// Each label beside its value. Two close together (a narrow normal band) go one above its line
  /// and one below its line rather than over each other; the lower is left out only when there
  /// is no room for both.
  void _labels(Canvas canvas) {
    final painters = [
      for (final (value, text) in labels)
        (
          _y(value),
          TextPainter(
            text: TextSpan(
              text: text,
              style: labelStyle.copyWith(color: colours.label),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout(),
        ),
    ];
    final tops = [
      for (final (y, p) in painters) (y - p.height / 2).clamp(0.0, plotHeight - p.height),
    ];
    if (painters.length == 2 && tops[1] < tops[0] + painters[0].$2.height) {
      final (yHigh, high) = painters[0];
      final (yLow, _) = painters[1];
      tops[0] = (yHigh - high.height).clamp(0.0, plotHeight - high.height);
      tops[1] = yLow > tops[0] + high.height ? yLow : tops[0] + high.height;
    }
    for (final (i, (_, painter)) in painters.indexed) {
      if (tops[i] + painter.height <= plotHeight) {
        painter.paint(canvas, Offset(gutter - 6 - painter.width, tops[i]));
      }
      painter.dispose();
    }
  }

  void _strip(Canvas canvas, double width) {
    final strip = RRect.fromLTRBR(
      gutter,
      plotHeight + stripGap,
      width,
      height,
      const Radius.circular(stripHeight / 2),
    );
    canvas
      ..save()
      ..clipRRect(strip)
      ..drawRRect(strip, Paint()..color = colours.stripNotYet);
    for (final (i, (h, state)) in coverage.indexed) {
      final end = i + 1 < coverage.length ? coverage[i + 1].$1 : 24;
      final colour = switch (state) {
        HourCoverage.data => colours.stripData,
        HourCoverage.missing => colours.stripMissing,
        HourCoverage.notYet => colours.stripNotYet,
      };
      // Overlap by half a pixel so no seam shows between hours of the same colour.
      canvas.drawRect(
        Rect.fromLTRB(
          xOf(h.toDouble(), width),
          strip.top,
          xOf(end.toDouble(), width) + 0.5,
          height,
        ),
        Paint()..color = colour,
      );
    }
    canvas.restore();
  }

  static void _dashed(Canvas canvas, Offset from, Offset to, Color colour) {
    const dash = 3.0;
    const gap = 3.0;
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1;
    final length = (to - from).distance;
    final step = (to - from) / length;
    for (var d = 0.0; d < length; d += dash + gap) {
      final end = d + dash < length ? d + dash : length;
      canvas.drawLine(from + step * d, from + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(HistoryDayPlot old) =>
      !mapEquals(old.hours, hours) ||
      !listEquals(old.clockHours, clockHours) ||
      !listEquals(old.coverage, coverage) ||
      old.low != low ||
      old.high != high ||
      old.normal != normal ||
      !setEquals(old.outside, outside) ||
      !listEquals(old.labels, labels) ||
      old.gutter != gutter ||
      old.picked != picked ||
      old.colours != colours ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
