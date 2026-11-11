import 'package:flutter/material.dart';

import '../../../domain/dashboard/reading_status.dart';
import '../../../domain/decoder/decoded_packet.dart';
import '../../../domain/models/reading.dart';
import '../../widgets/device_icons.dart';
import '../dashboard_format.dart';
import 'parts/arc_gauge.dart';
import 'parts/dash_card.dart';
import 'parts/status_pill.dart';
import 'parts/trace_chart.dart';

/// The dashboard's main card: the reading on an arc gauge with its normal band, its status, the
/// normal range and a trend line of the last 30 minutes.
class GaugeView extends StatelessWidget {
  const GaugeView({
    super.key,
    required this.reading,
    required this.value,
    required this.trend,
    required this.now,
    this.pairValue,
    this.live = false,
  });

  final Reading reading;
  final double? value;
  final double? pairValue;

  /// The reading's stored values from the last 30 minutes, oldest first.
  final List<Sample> trend;
  final DateTime now;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final value = this.value;
    final status = statusOf(reading, value, live: live);
    final word = l10n.statusWord(status);
    final text = value == null ? null : l10n.value(reading, value, pairValue: pairValue);
    final scale = scaleOf(reading);
    final normal = reading.normal;
    final footer = switch (l10n.footer(reading, status)) {
      final f? when normal != null && reading.unit.isNotEmpty => '$f ${reading.unit}',
      final f => f,
    };
    final fraction = switch ((value, scale, status.goalFraction)) {
      (_, _, final goal?) => goal.clamp(0.0, 1.0),
      (final v?, final s?, null) => scaleFraction(s, v),
      _ => null,
    };

    return Semantics(
      container: true,
      label: l10n.spoken(reading.label, text, reading.unit, word ?? footer),
      excludeSemantics: true,
      child: DashCard(
        child: Row(
          children: [
            ArcGauge(
              trackColor: tokens.chipBg,
              valueColor: status.isWarning ? tokens.warn : tokens.accent,
              value: fraction,
              band: scale == null || normal == null
                  ? null
                  : (scaleFraction(scale, normal.low), scaleFraction(scale, normal.high)),
              bandColor: tokens.ok.withAlpha(0x40),
              child: SizedBox(
                width: 112,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text ?? l10n.noValue,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reading.unit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _Details(reading, status, word, footer, trend, now)),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details(this.reading, this.status, this.word, this.footer, this.trend, this.now);

  final Reading reading;
  final ReadingStatus status;
  final String? word;
  final String? footer;
  final List<Sample> trend;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final muted = TextStyle(fontSize: 12, color: tokens.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(readingIconFor(reading.icon), size: 18, color: tokens.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reading.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (word case final w?) ...[const SizedBox(height: 7), StatusPill(w, kind: status.kind)],
        if (footer case final f?) ...[const SizedBox(height: 7), Text(f, style: muted)],
        const SizedBox(height: 7),
        TraceChart(
          lines: [
            [for (final sample in trend) sample.value],
          ],
          colors: [tokens.accent],
          area: tokens.soft,
        ),
        const SizedBox(height: 7),
        Text(switch (trend.lastOrNull) {
          final last? => l10n.trendCaption(l10n.ago(now.difference(last.at))),
          null => l10n.trendCaptionEmpty,
        }, style: muted.copyWith(fontSize: 11)),
      ],
    );
  }
}
