import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/history/summary_chart.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';
import '../widgets/dashed_border_box.dart';

/// The 7-day summary card (mockup 24): the reading's daily value title, the average of the days
/// and one bar per day, today last. A day without data is a dashed "No data" box; a value out of
/// the normal range is drawn in the warning colour and its row says High or Low, so colour is
/// never the only signal.
class HistorySummaryChart extends StatelessWidget {
  const HistorySummaryChart({super.key, required this.reading, required this.chart});

  final Reading reading;
  final SummaryChart chart;

  /// Bar heights, from the mockup: at least [_barBase] tall, [_barSpan] more for the highest.
  static const _barBase = 16.0;
  static const _barSpan = 110.0;
  static const _emptyBar = 40.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final title = l10n.historySummaryTitle(reading, chart.dailyValue);
    final avg = chart.avg;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.muted),
          ),
          if (avg != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 6,
              children: [
                Text(
                  l10n.value(reading, avg),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.historyAvgSuffix(reading),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.muted,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: l10n.historySummaryChartSpoken(title, chart.days.length),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, day) in chart.days.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _bar(context, tokens, day)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, AppTokens tokens, SummaryDay day) {
    final l10n = context.l10n;
    final value = day.value;
    final bar = value == null
        ? DashedBorderBox(
            color: tokens.danger,
            radius: 6,
            child: const SizedBox(height: _emptyBar, width: double.infinity),
          )
        : Container(
            height: _barBase + barFraction(chart, value) * _barSpan,
            decoration: BoxDecoration(
              color: _barColour(context, tokens, day),
              borderRadius: BorderRadius.circular(6),
            ),
          );
    return Semantics(
      container: true,
      label: l10n.historySummaryDayLabel(reading, day),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fitted(
            value == null ? l10n.historyNoData : l10n.value(reading, value),
            TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: value == null ? tokens.danger : tokens.muted,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 30), child: bar),
          const SizedBox(height: 6),
          _fitted(
            day.isToday ? l10n.historyToday : l10n.historyWeekday(day.day.start),
            TextStyle(
              fontSize: 11,
              fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w600,
              color: day.isToday ? context.textColor : tokens.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// A label that shrinks to its column rather than wrap or overflow at large text sizes.
  Widget _fitted(String text, TextStyle style) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, style: style),
  );

  Color _barColour(BuildContext context, AppTokens tokens, SummaryDay day) {
    if (day.flag != SummaryFlag.none) return tokens.warn;
    return day.isToday ? Theme.of(context).colorScheme.primary : tokens.barSoft;
  }
}
