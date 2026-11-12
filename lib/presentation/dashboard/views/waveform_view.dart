import 'package:flutter/material.dart';

import '../../../domain/dashboard/reading_status.dart';
import '../../../domain/models/reading.dart';
import '../dashboard_format.dart';
import 'parts/dash_card.dart';
import 'parts/trace_chart.dart';

/// A live trace on grid paper (mockup screen 20, ECG), with how the signal is doing at the top
/// right and up to three readings in a row under it.
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.title,
    required this.samples,
    required this.capacity,
    required this.seconds,
    this.scaleLabel,
    this.status,
    this.stats = const [],
  });

  final String title;

  /// The latest samples, oldest first.
  final List<double> samples;

  /// How many samples fill the width.
  final int capacity;

  /// Seconds the width stands for ("−6 s").
  final int seconds;
  final String? scaleLabel;

  /// A state reading and its value shown at the top right, e.g. "Signal good".
  final (Reading, double?)? status;

  /// Readings and their values shown under the trace.
  final List<(Reading, double?)> stats;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final small = TextStyle(fontSize: 10, color: tokens.muted);
    final (statusText, statusColor) = _text(context, status);

    return DashCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tokens.danger, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (statusText != null)
                Text(
                  statusText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            image: true,
            label: l10n.waveformSpoken(title),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              child: TraceChart(
                lines: [samples],
                colors: [tokens.danger],
                height: 120,
                strokeWidth: 1.6,
                slots: capacity,
                grid: (
                  paper: Color.alphaBlend(tokens.danger.withAlpha(0x0A), tokens.surface),
                  line: Color.alphaBlend(tokens.danger.withAlpha(0x26), tokens.surface),
                  cell: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.axisSecondsAgo(seconds), style: small),
              if (scaleLabel case final label?) Text(label, style: small),
              Text(l10n.axisNow, style: small),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, stat) in stats.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _Stat(stat)),
                ],
                for (var i = stats.length; i < 3; i++) ...[
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A reading's text and colour: a coded state's name in its colour, else the value and unit.
(String?, Color?) _text(BuildContext context, (Reading, double?)? stat) {
  if (stat == null) return (null, null);
  final (reading, value) = stat;
  if (value == null) return (context.l10n.noValue, context.tokens.muted);
  final status = statusOf(reading, value);
  if (status.word == StatusWord.state) {
    return (status.label, kindColors(context.tokens, status.kind).$1);
  }
  final text = context.l10n.value(reading, value);
  return (reading.unit.isEmpty ? text : '$text ${reading.unit}', null);
}

class _Stat extends StatelessWidget {
  const _Stat(this.stat);

  final (Reading, double?) stat;

  @override
  Widget build(BuildContext context) {
    final (reading, _) = stat;
    final (text, color) = _text(context, stat);
    return Semantics(
      container: true,
      label: context.l10n.readingSpoken(reading.label, text ?? context.l10n.noReadingSpoken),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reading.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.tokens.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text ?? '',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
