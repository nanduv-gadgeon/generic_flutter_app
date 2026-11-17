import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/history_provider.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';
import 'history_day_plot.dart';

/// A reading through the day (requirement 6.4, mockup 22 and 28, made easier to read): each hour
/// with data is a bar from its lowest to its highest value with a dot at its average, joined by a
/// line to neighbouring hours, over the normal range (green). A strip under it marks the missing
/// hours in red, and the clock times are under that. Tapping or dragging across picks an hour and
/// writes its figures above the chart. Screen readers hear the lowest and highest hourly average
/// and the missing hours; the card writes the gaps out too.
class HistoryDayChart extends ConsumerStatefulWidget {
  const HistoryDayChart({
    super.key,
    required this.deviceId,
    required this.reading,
    required this.day,
    required this.withData,
    required this.toCheck,
  });

  final int deviceId;
  final Reading reading;
  final HistoryDay day;

  /// The wall-clock hours in which this reading arrived.
  final Set<int> withData;

  /// The hours that should have data ([hoursToCheck]); later hours of today are not missing.
  final Set<int> toCheck;

  /// The drawing, for tests.
  static const plotKey = ValueKey('historyDayPlot');

  static const _labelStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600);

  @override
  ConsumerState<HistoryDayChart> createState() => _HistoryDayChartState();
}

class _HistoryDayChartState extends ConsumerState<HistoryDayChart> {
  int? _picked;

  @override
  void didUpdateWidget(HistoryDayChart old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day || old.deviceId != widget.deviceId) _picked = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final reading = widget.reading;
    final day = widget.day;
    final data = ref.watch(historyDayHoursProvider(widget.deviceId, day.start)).value;
    final stats = data == null ? const <int, HourFigures>{} : hourlyStats(data, reading.key);
    final picked = stats[_picked];
    final gaps = hourRanges(missingHours(widget.withData, widget.toCheck), day);
    final labels = stats.isEmpty ? const <(double, String)>[] : _labels(context, stats);
    final scaler = MediaQuery.textScalerOf(context);
    final gutter = labels.isEmpty ? 0.0 : _gutter(labels, scaler);
    const ticks = <int?>[0, 6, 12, 18, null];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.isNotEmpty) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _picked != null && picked != null
                  ? l10n.historyHourText(reading, day, _picked!, picked)
                  : l10n.historyChartHint,
              style: TextStyle(
                fontSize: 12,
                fontWeight: picked == null ? FontWeight.w500 : FontWeight.w700,
                color: picked == null ? tokens.muted : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          container: true,
          label: stats.isEmpty ? null : _spoken(context, stats.values.map((f) => f.avg), gaps),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: HistoryDayPlot.height,
                child: stats.isEmpty ? null : _plot(context, stats, labels, gutter, scaler),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: gutter),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final h in ticks)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.historyHour(day, h),
                            style: TextStyle(fontSize: 10, color: tokens.muted),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plot(
    BuildContext context,
    Map<int, HourFigures> stats,
    List<(double, String)> labels,
    double gutter,
    TextScaler scaler,
  ) {
    final tokens = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final normal = widget.reading.normal;
    final range = chartRange([
      for (final f in stats.values) ...[f.min, f.max],
    ], normal: normal);
    final HistoryPlotColours colours = (
      frame: tokens.chipBg.withValues(alpha: dark ? 0.5 : 0.45),
      grid: tokens.border,
      band: tokens.ok.withValues(alpha: dark ? 0.14 : 0.09),
      bandEdge: tokens.ok.withValues(alpha: dark ? 0.55 : 0.4),
      range: tokens.accent.withValues(alpha: dark ? 0.32 : 0.22),
      line: tokens.accent,
      outside: _lighter(tokens.warn),
      ring: tokens.surface,
      picked: tokens.accent.withValues(alpha: dark ? 0.16 : 0.1),
      label: tokens.muted,
      stripData: tokens.accent,
      stripMissing: tokens.danger.withValues(alpha: dark ? 0.75 : 0.65),
      stripNotYet: tokens.chipBg,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        int? hourAt(double dx) {
          final at = (dx - gutter) / (width - gutter) * 24;
          return nearestHour(stats.keys, at.clamp(0.0, 24.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final h = hourAt(d.localPosition.dx);
            setState(() => _picked = h == _picked ? null : h);
          },
          onHorizontalDragStart: (d) => setState(() => _picked = hourAt(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => setState(() => _picked = hourAt(d.localPosition.dx)),
          child: CustomPaint(
            key: HistoryDayChart.plotKey,
            size: Size(width, HistoryDayPlot.height),
            painter: HistoryDayPlot(
              hours: stats,
              clockHours: widget.day.clockHours,
              coverage: hourCoverage(widget.day, widget.withData, widget.toCheck),
              low: range.low,
              high: range.high,
              normal: normal == null ? null : (normal.low, normal.high),
              outside: {
                for (final MapEntry(key: h, value: f) in stats.entries)
                  if (sideOfNormal(f.avg, normal, widget.reading.decimals) != null) h,
              },
              labels: labels,
              gutter: gutter,
              picked: stats.containsKey(_picked) ? _picked : null,
              colours: colours,
              labelStyle: HistoryDayChart._labelStyle,
              textScaler: scaler,
            ),
          ),
        );
      },
    );
  }

  /// The values written at the left, highest first: the normal range's limits, or without one the
  /// day's lowest and highest value.
  List<(double, String)> _labels(BuildContext context, Map<int, HourFigures> stats) {
    final l10n = context.l10n;
    final reading = widget.reading;
    final (low, high) = switch (reading.normal) {
      final n? => (n.low, n.high),
      null => (
        stats.values.map((f) => f.min).reduce((a, b) => a < b ? a : b),
        stats.values.map((f) => f.max).reduce((a, b) => a > b ? a : b),
      ),
    };
    return [(high, l10n.value(reading, high)), if (low != high) (low, l10n.value(reading, low))];
  }

  /// The theme's warning colour, lightened to at least half lightness so an out-of-range ring
  /// cannot be taken for the red of the missing hours (the light theme's amber is dark).
  static Color _lighter(Color warn) {
    final hsl = HSLColor.fromColor(warn);
    return hsl.lightness >= 0.5 ? warn : hsl.withLightness(0.5).toColor();
  }

  /// The width kept at the left for [labels], with a gap before the plot.
  static double _gutter(List<(double, String)> labels, TextScaler scaler) {
    var widest = 0.0;
    for (final (_, text) in labels) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: HistoryDayChart._labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest + 6;
  }

  String _spoken(BuildContext context, Iterable<double> averages, List<(int, int)> gaps) {
    final l10n = context.l10n;
    final reading = widget.reading;
    String said(double v) {
      final value = l10n.value(reading, v);
      return reading.unit.isEmpty ? value : l10n.historyValueWithUnit(value, reading.unit);
    }

    final low = said(averages.reduce((a, b) => a < b ? a : b));
    final high = said(averages.reduce((a, b) => a > b ? a : b));
    final day = widget.day;
    return gaps.isEmpty
        ? l10n.historyChartSpoken(reading.label, low, high)
        : l10n.historyChartGapsSpoken(reading.label, low, high, l10n.historyRanges(day, gaps));
  }
}
