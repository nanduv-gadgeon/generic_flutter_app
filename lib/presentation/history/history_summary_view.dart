import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/device_profiles_provider.dart';
import '../../application/history_provider.dart';
import '../../application/history_summary_provider.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/reading.dart';
import '../dashboard/dashboard_format.dart';
import '../widgets/dashed_border_box.dart';
import 'history_summary_chart.dart';
import 'history_summary_list.dart';

/// The 7-day summary tab of History (requirement 6.5, mockup 24): a chip per reading, then the
/// picked reading's chart, its Min / Average / Max and the day list.
class HistorySummaryView extends ConsumerWidget {
  const HistorySummaryView({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final readings = ref.watch(historyReadingListProvider(deviceId));
    final reading = summaryReading(
      readings,
      ref.watch(historyControllerProvider.select((p) => p.readingKey)),
    );
    if (reading == null) {
      // No readings yet while the profiles load; afterwards the device has none to show.
      return ref.watch(deviceProfileRegistryProvider).value == null
          ? _Loading(label: l10n.historySummaryLoading)
          : _Message(text: l10n.historySummaryNoReadings);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HistoryReadingChips(
          readings: readings,
          selectedKey: reading.key,
          onPick: ref.read(historyControllerProvider.notifier).pickReading,
        ),
        const SizedBox(height: 14),
        _Summary(deviceId: deviceId, reading: reading),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.deviceId, required this.reading});

  final int deviceId;
  final Reading reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chart = ref.watch(historySummaryChartProvider(deviceId, reading.key));
    // Keeps the last figures on screen while the next minute's load.
    if (chart.value case final value?) {
      if (!value.hasData) return _Message(text: l10n.historySummaryEmpty(value.days.length));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HistorySummaryChart(reading: reading, chart: value),
          const SizedBox(height: 14),
          HistorySummaryTiles(reading: reading, chart: value),
          const SizedBox(height: 14),
          HistorySummaryDayList(reading: reading, chart: value),
        ],
      );
    }
    if (chart.hasError) {
      return Text(l10n.historySummaryFailed, style: TextStyle(color: context.tokens.danger));
    }
    if (chart.hasValue) return _Message(text: l10n.historySummaryNoReadings);
    return _Loading(label: l10n.historySummaryLoading);
  }
}

/// One chip per reading, scrolling sideways; the picked one is tinted (mockup 24, under the
/// tabs).
class HistoryReadingChips extends StatelessWidget {
  const HistoryReadingChips({
    super.key,
    required this.readings,
    required this.selectedKey,
    required this.onPick,
  });

  final List<Reading> readings;
  final String selectedKey;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      label: context.l10n.historyReadingsSpoken,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, reading) in readings.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              _chip(reading, reading.key == selectedKey, tokens),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(Reading reading, bool on, AppTokens tokens) => Semantics(
    button: true,
    selected: on,
    label: reading.label,
    excludeSemantics: true,
    child: Material(
      color: on ? tokens.soft : tokens.chipBg,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: on ? null : () => onPick(reading.key),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Center(
              widthFactor: 1,
              child: Text(
                reading.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? tokens.accent : tokens.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      child: const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DashedBorderBox(
      color: tokens.border,
      radius: tokens.radius,
      background: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: tokens.muted),
      ),
    );
  }
}
