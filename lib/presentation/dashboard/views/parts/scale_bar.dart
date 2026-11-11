import 'package:flutter/material.dart';

import '../../dashboard_format.dart';

/// A part of a [ScaleBar]'s track from [start] to [end] (0–1) in [color].
typedef BarBand = ({double start, double end, Color color});

/// One horizontal bar for every dashboard scale: a track with optional coloured [bands] (normal
/// range, or zones), an optional [fill] from the left (goal progress) and an optional [marker]
/// (the value). Positions are 0–1 along the bar. With [joined] the bands meet as one bar with
/// rounded ends only (zones); otherwise each band has rounded ends (a normal range).
class ScaleBar extends StatelessWidget {
  const ScaleBar({
    super.key,
    this.height = 6,
    this.bands = const [],
    this.fill,
    this.fillColor,
    this.marker,
    this.markerColor,
    this.markerSize = 14,
    this.joined = false,
  });

  final double height;
  final List<BarBand> bands;
  final double? fill;
  final Color? fillColor;
  final double? marker;

  /// The marker's ring colour.
  final Color? markerColor;
  final double markerSize;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(height / 2);
    return SizedBox(
      height: marker == null ? height : markerSize,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          Widget part(double start, double end, Color color, {bool round = true}) => Positioned(
            left: start * width,
            width: ((end - start) * width).clamp(0, width),
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: round ? radius : null),
            ),
          );
          final marker = this.marker;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              part(0, 1, tokens.chipBg),
              if (joined)
                Positioned(
                  left: 0,
                  width: width,
                  height: height,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      children: [
                        for (final band in bands)
                          part(band.start, band.end, band.color, round: false),
                      ],
                    ),
                  ),
                )
              else
                for (final band in bands) part(band.start, band.end, band.color),
              if (fill case final f?) part(0, f.clamp(0, 1), fillColor ?? tokens.accent),
              if (marker != null)
                Positioned(
                  left: marker.clamp(0, 1) * width - markerSize / 2,
                  child: Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: markerColor ?? tokens.ok, width: 3),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
