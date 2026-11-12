import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Grid paper behind a [TraceChart], e.g. the ECG's 15 px squares.
typedef GridPaper = ({Color paper, Color line, double cell});

/// One line chart for every dashboard trace: the gauge's 30-minute trend (with [area]) and a live
/// waveform (with [grid]). Each of [lines] is drawn in the matching [colors] entry, scaled
/// together to fit the height. With [slots], points take fixed steps and the newest is at the
/// right edge, so a trace fills in from the right as samples arrive.
class TraceChart extends StatelessWidget {
  const TraceChart({
    super.key,
    required this.lines,
    required this.colors,
    this.height = 34,
    this.strokeWidth = 2.2,
    this.area,
    this.grid,
    this.slots,
  });

  final List<List<double>> lines;
  final List<Color> colors;
  final double height;
  final double strokeWidth;

  /// Fills under the first line in this colour.
  final Color? area;
  final GridPaper? grid;
  final int? slots;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _TracePainter(this)),
  );
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.chart);

  final TraceChart chart;

  /// Space above and below the lines, so round caps are not cut off.
  static const _pad = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (chart.grid case final grid?) _paintGrid(canvas, size, grid);
    final values = chart.lines.expand((l) => l);
    if (values.isEmpty) return;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = high - low;
    double y(double v) => span == 0
        ? size.height / 2
        : size.height - _pad - (v - low) / span * (size.height - 2 * _pad);

    for (final (i, line) in chart.lines.indexed) {
      if (line.isEmpty) continue;
      final slots = chart.slots ?? line.length;
      final step = slots < 2 ? 0.0 : size.width / (slots - 1);
      final first = size.width - (line.length - 1) * step;
      final path = Path()..moveTo(first, y(line.first));
      for (var j = 1; j < line.length; j++) {
        path.lineTo(first + j * step, y(line[j]));
      }
      if (i == 0 && chart.area != null) {
        final fill = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(first, size.height)
          ..close();
        canvas.drawPath(fill, Paint()..color = chart.area!);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = chart.colors[i % chart.colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = chart.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size, GridPaper grid) {
    canvas.drawRect(Offset.zero & size, Paint()..color = grid.paper);
    final line = Paint()
      ..color = grid.line
      ..strokeWidth = 1;
    for (var x = grid.cell; x < size.width; x += grid.cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = grid.cell; y < size.height; y += grid.cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.chart.lines != chart.lines ||
      old.chart.colors != chart.colors ||
      old.chart.area != chart.area ||
      old.chart.grid != chart.grid;
}
