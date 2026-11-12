import 'package:flutter/material.dart';

import '../../../domain/dashboard/reading_status.dart';
import '../../../domain/decoder/decoded_packet.dart';
import '../../../domain/models/reading.dart';
import '../../widgets/dashed_border_box.dart';
import '../dashboard_format.dart';
import 'parts/dash_card.dart';
import 'parts/section_title.dart';
import 'parts/status_pill.dart';

/// "Today's readings": each of today's readings, newest first, with its time and zone.
class ReadingListView extends StatelessWidget {
  const ReadingListView({super.key, required this.reading, required this.samples});

  final Reading reading;

  /// Today's readings, oldest first, as stored.
  final List<Sample> samples;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final rows = samples.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.todaysReadings, trailing: l10n.readingsCount(rows.length)),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          DashedBorderBox(
            color: tokens.border,
            radius: tokens.radius,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: Text(
              l10n.nothingToShow,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: tokens.muted),
            ),
          )
        else
          DashCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, sample) in rows.indexed) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
                  _Row(reading: reading, sample: sample),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.reading, required this.sample});

  final Reading reading;
  final Sample sample;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final status = statusOf(reading, sample.value);
    final word = l10n.statusWord(status);
    final value = l10n.value(reading, sample.value);
    final time = l10n.time(sample.at);
    return Semantics(
      container: true,
      label: '$time, ${l10n.spoken(reading.label, value, reading.unit, word)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 54),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.chipBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: tokens.muted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reading.unit.isEmpty ? value : '$value ${reading.unit}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            if (word != null) StatusPill(word, kind: status.kind, height: 22, fontSize: 11),
          ],
        ),
      ),
    );
  }
}
