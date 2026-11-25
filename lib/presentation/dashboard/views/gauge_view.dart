import 'package:flutter/material.dart';

import '../../../domain/dashboard/reading_status.dart';
import '../../../domain/decoder/decoded_packet.dart';
import '../../../domain/models/reading.dart';
import '../../widgets/device_icons.dart';
import '../../widgets/text_fit.dart';
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
    this.updatedAt,
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

  /// When [value] was measured, for the caption when the trend has nothing in its 30 minutes
  /// (e.g. a therapy device's last logged current from an hour ago).
  final DateTime? updatedAt;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The arc grows with the text size, up to the card's width, so the number and unit
            // stay inside the ring.
            final grow = MediaQuery.textScalerOf(context).scale(_valueSize) / _valueSize;
            final size = (_arcSize * grow).clamp(_arcSize, constraints.maxWidth).toDouble();
            final gauge = ArcGauge(
              size: size,
              trackColor: tokens.chipBg,
              valueColor: status.isWarning ? tokens.warn : tokens.accent,
              value: fraction,
              band: scale == null || normal == null
                  ? null
                  : (scaleFraction(scale, normal.low), scaleFraction(scale, normal.high)),
              bandColor: tokens.ok.withAlpha(0x40),
              child: SizedBox(
                width: size * _readoutShare,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text ?? l10n.noValue,
                        style: const TextStyle(
                          fontSize: _valueSize,
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
            );
            final details = _Details(
              reading,
              status,
              word,
              footer,
              trend,
              now,
              value == null ? null : updatedAt,
            );
            // Beside the arc as in the mockup while the reading's label fits on one line there;
            // with large text the details go under the arc, so the label is not cut off.
            final beside = constraints.maxWidth - gauge.size - _gap;
            if (!fitsOnOneLine(context, [reading.label], _labelStyle, beside - _labelIcon)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: gauge),
                  const SizedBox(height: 14),
                  details,
                ],
              );
            }
            return Row(
              children: [
                gauge,
                const SizedBox(width: _gap),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _gap = 14.0;

  /// The arc at normal text size, the number's font size, and how much of the arc's width the
  /// number may take (112 of 132 px, as in the mockup).
  static const _arcSize = 132.0;
  static const _valueSize = 30.0;
  static const _readoutShare = 112 / 132;
  static const _labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  /// The reading's icon and the space after it, before its label.
  static const _labelIcon = 26.0;
}

class _Details extends StatelessWidget {
  const _Details(
    this.reading,
    this.status,
    this.word,
    this.footer,
    this.trend,
    this.now,
    this.updatedAt,
  );

  final Reading reading;
  final ReadingStatus status;
  final String? word;
  final String? footer;
  final List<Sample> trend;
  final DateTime now;
  final DateTime? updatedAt;

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
              // One line beside the arc (GaugeView checks it fits); under the arc it may wrap.
              child: Text(reading.label, style: GaugeView._labelStyle),
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
        Text(switch ((trend.lastOrNull, updatedAt)) {
          (final last?, _) => l10n.trendCaption(l10n.ago(now.difference(last.at))),
          (null, final at?) => l10n.trendCaptionLastReading(l10n.ago(now.difference(at))),
          _ => l10n.trendCaptionEmpty,
        }, style: muted.copyWith(fontSize: 11)),
      ],
    );
  }
}
