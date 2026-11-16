import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/history_provider.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';

/// A reading through the day (requirement 6.4, mockup 22 and 28): its average in each hour as a
/// line, broken where no readings arrived, over the normal range (green), with the missing hours
/// shaded red and the clock times under it. Screen readers hear the lowest and highest hourly
/// average and the missing hours; the card writes the gaps out too.
class HistoryDayChart extends ConsumerWidget {
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

  static const _height = 70.0;

  /// How strongly the missing hours are shaded in the theme's danger colour.
  static const missingAlphaLight = 0.12;
  static const missingAlphaDark = 0.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final hours = ref.watch(historyDayHoursProvider(deviceId, day.start)).value;
    final averages = hours == null ? const <int, double>{} : hourlyAverages(hours, reading.key);
    final gaps = hourRanges(missingHours(withData, toCheck), day);
    const ticks = <int?>[0, 6, 12, 18, null];

    return Semantics(
      container: true,
      label: averages.isEmpty ? null : _spoken(context, averages.values, gaps),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _height,
            child: averages.isEmpty ? null : _chart(context, averages, gaps),
          ),
          const SizedBox(height: 6),
          Row(
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
        ],
      ),
    );
  }

  /// The shading (normal range, then the missing hours on top) under the line.
  Widget _chart(BuildContext context, Map<int, double> averages, List<(int, int)> gaps) {
    final tokens = context.tokens;
    final normal = reading.normal;
    final range = chartRange(averages.values, normal: normal);
    // Solid: the danger colour laid over the card once, so the missing hours look the same on
    // every card whether or not the normal range is behind them. A faint tint disappears on a
    // dark card, so dark mode shades them more strongly.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final missing = Color.alphaBlend(
      tokens.danger.withValues(alpha: dark ? missingAlphaDark : missingAlphaLight),
      tokens.surface,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        HistoryChartShading(
          low: range.low,
          high: range.high,
          normal: normal == null ? null : (normal.low, normal.high),
          gaps: [
            for (final (first, last) in gaps)
              (first.toDouble(), (nextHourOf(day, last) ?? 24).toDouble()),
          ],
          normalColour: tokens.ok.withValues(alpha: 0.1),
          missingColour: missing,
        ),
        LineChart(
          LineChartData(
            // One unit per hour; each average sits in the middle of its hour.
            minX: 0,
            maxX: 24,
            minY: range.low,
            maxY: range.high,
            clipData: const FlClipData.all(),
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final h in day.clockHours)
                    if (averages[h] case final v?) FlSpot(h + 0.5, v) else FlSpot.nullSpot,
                ],
                color: tokens.accent,
                barWidth: 2,
                isStrokeCapRound: true,
                isStrokeJoinRound: true,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
          duration: Duration.zero,
        ),
      ],
    );
  }

  String _spoken(BuildContext context, Iterable<double> averages, List<(int, int)> gaps) {
    final l10n = context.l10n;
    String said(double v) {
      final value = l10n.value(reading, v);
      return reading.unit.isEmpty ? value : l10n.historyValueWithUnit(value, reading.unit);
    }

    final low = said(averages.reduce((a, b) => a < b ? a : b));
    final high = said(averages.reduce((a, b) => a > b ? a : b));
    return gaps.isEmpty
        ? l10n.historyChartSpoken(reading.label, low, high)
        : l10n.historyChartGapsSpoken(reading.label, low, high, l10n.historyRanges(day, gaps));
  }
}

/// The background of a chart through the day: the normal range as a band, then the missing hours
/// on top, so they always look the same. Hours run 0–24 across, values [low]–[high] up.
class HistoryChartShading extends StatelessWidget {
  const HistoryChartShading({
    super.key,
    required this.low,
    required this.high,
    required this.normal,
    required this.gaps,
    required this.normalColour,
    required this.missingColour,
  });

  final double low;
  final double high;

  /// The normal range (low, high); none when null.
  final (double, double)? normal;

  /// The missing hours as (from, to) in hours of the day, e.g. (2, 6) for 02:00–06:00.
  final List<(double, double)> gaps;
  final Color normalColour;
  final Color missingColour;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ShadingPainter(this));
}

class _ShadingPainter extends CustomPainter {
  const _ShadingPainter(this.s);

  final HistoryChartShading s;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double value) => size.height * (s.high - value) / (s.high - s.low);
    double x(double hour) => size.width * hour / 24;
    if (s.normal case (final from, final to) when to > s.low && from < s.high) {
      final top = y(to < s.high ? to : s.high);
      final bottom = y(from > s.low ? from : s.low);
      canvas.drawRect(Rect.fromLTRB(0, top, size.width, bottom), Paint()..color = s.normalColour);
    }
    final missing = Paint()..color = s.missingColour;
    for (final (from, to) in s.gaps) {
      canvas.drawRect(Rect.fromLTRB(x(from), 0, x(to), size.height), missing);
    }
  }

  @override
  bool shouldRepaint(_ShadingPainter old) =>
      old.s.low != s.low ||
      old.s.high != s.high ||
      old.s.normal != s.normal ||
      old.s.normalColour != s.normalColour ||
      old.s.missingColour != s.missingColour ||
      !_sameGaps(old.s.gaps, s.gaps);

  static bool _sameGaps(List<(double, double)> a, List<(double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
