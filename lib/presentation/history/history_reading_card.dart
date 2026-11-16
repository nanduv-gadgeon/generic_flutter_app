import 'package:flutter/material.dart';

import '../../application/history_provider.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import '../strings/history_strings.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/device_icons.dart';
import 'history_day_chart.dart';

/// One reading on By day (mockup 22, 28): its day's Min / Average / Max with its chart through the
/// day and the missing hours, or its value against the goal, or "No data received this day".
class HistoryReadingCard extends StatelessWidget {
  const HistoryReadingCard({
    super.key,
    required this.deviceId,
    required this.reading,
    required this.detail,
  });

  final int deviceId;
  final Reading reading;
  final HistoryDayDetail detail;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final summary = detail.summaries[reading.key];
    final goal = reading.goal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(reading: reading, showUnit: goal == null),
          const SizedBox(height: 10),
          if (summary == null)
            const _NoData()
          else if (goal != null)
            // A reading with a goal counts up through the day: its highest value is the total.
            _GoalProgress(reading: reading, value: summary.max, goal: goal)
          else
            ..._figures(context, summary),
        ],
      ),
    );
  }

  List<Widget> _figures(BuildContext context, DaySummary summary) {
    final l10n = context.l10n;
    final hours = detail.hoursOf(reading.key);
    final gaps = hourRanges(missingHours(hours, detail.toCheck), detail.day);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Figure(label: l10n.historyMin, value: l10n.value(reading, summary.min)),
          _Figure(label: l10n.historyAverage, value: l10n.value(reading, summary.avg)),
          _Figure(label: l10n.historyMax, value: l10n.value(reading, summary.max)),
        ],
      ),
      const SizedBox(height: 12),
      HistoryDayChart(
        deviceId: deviceId,
        reading: reading,
        day: detail.day,
        withData: hours,
        toCheck: detail.toCheck,
      ),
      if (gaps.isNotEmpty) ...[
        const SizedBox(height: 8),
        ExcludeSemantics(
          // The chart already says the missing hours to screen readers.
          child: Text(
            l10n.historyGapNote(l10n.historyRanges(detail.day, gaps)),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.tokens.danger,
            ),
          ),
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.reading, required this.showUnit});

  final Reading reading;
  final bool showUnit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(readingIconFor(reading.icon), size: 18, color: tokens.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              reading.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (showUnit && reading.unit.isNotEmpty)
          Text(reading.unit, style: TextStyle(fontSize: 12, color: tokens.muted)),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.muted),
        ),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

/// "6,482 of 10,000 goal" and a progress bar, from the day's total (its highest value).
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.reading, required this.value, required this.goal});

  final Reading reading;
  final double value;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final fraction = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          children: [
            Text(
              l10n.value(reading, value),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                l10n.historyGoalOf(l10n.value(reading, goal)),
                style: TextStyle(fontSize: 13, color: tokens.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          // The value and goal above say it in words.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: tokens.chipBg,
              color: tokens.accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// "No data received this day" in a dashed box (TC-1.4-007): never zeros.
class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DashedBorderBox(
      color: tokens.border,
      radius: tokens.radiusSmall,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Text(
        context.l10n.historyNoDataDay,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: tokens.muted),
      ),
    );
  }
}
