import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A 270° gauge opening at the bottom (mockup screens 13–21): a track, the normal [band] and the
/// [value] arc, with [child] (the number) in the middle. Positions are 0–1 along the arc, from
/// the lower left, clockwise.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.child,
    required this.trackColor,
    required this.valueColor,
    this.value,
    this.band,
    this.bandColor,
    this.size = 132,
  });

  final Widget child;
  final Color trackColor;
  final Color valueColor;
  final double? value;
  final (double, double)? band;
  final Color? bandColor;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _ArcPainter(
        value: value,
        band: band,
        trackColor: trackColor,
        valueColor: valueColor,
        bandColor: bandColor,
      ),
      child: Center(child: child),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.value,
    required this.band,
    required this.trackColor,
    required this.valueColor,
    required this.bandColor,
  });

  final double? value;
  final (double, double)? band;
  final Color trackColor;
  final Color valueColor;
  final Color? bandColor;

  static const _start = 3 * math.pi / 4; // Lower left.
  static const _sweep = 3 * math.pi / 2; // 270°.

  @override
  void paint(Canvas canvas, Size size) {
    // The mockup's 120-unit drawing: radius 50, stroke 10.
    final scale = size.shortestSide / 120;
    final stroke = 10 * scale;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 50 * scale);
    Paint paint(Color color, StrokeCap cap) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = cap;

    canvas.drawArc(rect, _start, _sweep, false, paint(trackColor, StrokeCap.round));
    if ((band, bandColor) case ((final from, final to), final color?) when to > from) {
      canvas.drawArc(
        rect,
        _start + from.clamp(0, 1) * _sweep,
        (to.clamp(0, 1) - from.clamp(0, 1)) * _sweep,
        false,
        paint(color, StrokeCap.butt),
      );
    }
    if (value case final v? when v > 0) {
      canvas.drawArc(
        rect,
        _start,
        v.clamp(0, 1) * _sweep,
        false,
        paint(valueColor, StrokeCap.round),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value ||
      old.band != band ||
      old.trackColor != trackColor ||
      old.valueColor != valueColor ||
      old.bandColor != bandColor;
}
