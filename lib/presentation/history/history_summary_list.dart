import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/history/summary_chart.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';

/// Min / Average / Max of the days' values, under the 7-day summary chart (mockup 24).
class HistorySummaryTiles extends StatelessWidget {
  const HistorySummaryTiles({super.key, required this.reading, required this.chart});

  final Reading reading;
  final SummaryChart chart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final figures = [
      (l10n.historyMin, chart.min),
      (l10n.historyAverage, chart.avg),
      (l10n.historyMax, chart.max),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, value)) in figures.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _tile(context, label, value)),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, String label, double? value) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _box(tokens),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.muted),
          ),
          Text(
            value == null ? '–' : context.l10n.value(reading, value),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// One row per day, newest first: the date, the day's value and its status in words (mockup 24).
class HistorySummaryDayList extends StatelessWidget {
  const HistorySummaryDayList({super.key, required this.reading, required this.chart});

  final Reading reading;
  final SummaryChart chart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final days = chart.days.reversed.toList();
    return Container(
      decoration: _box(tokens),
      child: Column(
        children: [
          for (final (i, day) in days.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: tokens.border)),
              ),
              child: _row(context, tokens, day),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppTokens tokens, SummaryDay day) {
    final l10n = context.l10n;
    final value = day.value;
    final status = rowStatus(day);
    final date = l10n.historyBannerDate(day.day.start);
    final unit = l10n.historyUnitOf(reading);
    return Semantics(
      label: l10n.historySummaryDayLabel(reading, day),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                day.isToday ? l10n.historyTodayDate(date) : date,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            // Value and status wrap under each other when large text leaves no room.
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 2,
                children: [
                  if (value == null)
                    Text(
                      l10n.historyNoData,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: tokens.danger,
                      ),
                    )
                  else
                    Text.rich(
                      TextSpan(
                        text: l10n.value(reading, value),
                        children: [
                          if (unit.isNotEmpty)
                            TextSpan(
                              text: ' $unit',
                              style: TextStyle(fontWeight: FontWeight.w500, color: tokens.muted),
                            ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 64),
                    child: Text(
                      l10n.historyRowStatus(status),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColour(tokens, status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColour(AppTokens tokens, SummaryRowStatus status) => switch (status) {
    SummaryRowStatus.missing => tokens.danger,
    SummaryRowStatus.high || SummaryRowStatus.low || SummaryRowStatus.partial => tokens.warn,
    SummaryRowStatus.normal => tokens.ok,
  };
}

BoxDecoration _box(AppTokens tokens) => BoxDecoration(
  color: tokens.surface,
  border: Border.all(color: tokens.border),
  borderRadius: BorderRadius.circular(tokens.radius),
);
