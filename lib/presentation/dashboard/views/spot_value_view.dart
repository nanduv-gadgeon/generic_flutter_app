import 'package:flutter/material.dart';

import '../../../domain/dashboard/reading_status.dart';
import '../../../domain/decoder/decoded_packet.dart';
import '../../../domain/models/reading.dart';
import '../dashboard_format.dart';
import 'parts/dash_card.dart';
import 'parts/scale_bar.dart';
import 'parts/status_pill.dart';
import 'reading_tile.dart';

/// The latest reading of a device that sends one when used (mockup screen 18): a large value, its
/// zone, when it was measured, and a bar of the reading's zones with the value's marker.
class SpotValueView extends StatelessWidget {
  const SpotValueView({super.key, required this.reading, required this.latest});

  final Reading reading;

  /// Today's latest reading, if there is one.
  final Sample? latest;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final latest = this.latest;
    final status = statusOf(reading, latest?.value);
    final word = l10n.statusWord(status);
    final text = latest == null ? null : l10n.value(reading, latest.value);
    final muted = TextStyle(fontSize: 12, color: tokens.muted);

    return Semantics(
      container: true,
      label: l10n.spoken(reading.label, text, reading.unit, word),
      excludeSemantics: true,
      child: DashCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              l10n.lastReading.toUpperCase(),
              style: muted.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ValueWithUnit(value: text ?? l10n.noValue, unit: reading.unit, size: 52),
                ),
              ],
            ),
            if (word != null) ...[
              const SizedBox(height: 6),
              StatusPill(word, kind: status.kind, height: 26, fontSize: 13),
            ],
            const SizedBox(height: 6),
            Text(
              latest == null ? l10n.noReadingYet : l10n.measuredTodayAt(l10n.time(latest.at)),
              style: muted,
            ),
            ..._zoneBar(context, latest?.value),
          ],
        ),
      ),
    );
  }

  List<Widget> _zoneBar(BuildContext context, double? value) {
    final scale = reading.scale;
    final zones = reading.zones;
    if (scale == null || zones.isEmpty) return const [];
    final tokens = context.tokens;
    final l10n = context.l10n;
    final bands = <BarBand>[];
    final labels = <String>[];
    double? from;
    for (final zone in zones) {
      final (color, _) = kindColors(tokens, zone.kind);
      final to = zone.below;
      bands.add((
        start: from == null ? 0 : scaleFraction(scale, from),
        end: to == null ? 1 : scaleFraction(scale, to),
        color: color,
      ));
      String n(double v) => l10n.value(reading, v);
      labels.add(switch ((from, to)) {
        (null, final to?) => l10n.zoneBelow(zone.label, n(to)),
        (final from?, final to?) => l10n.zoneBetween(zone.label, n(from), n(to)),
        (final from?, null) => l10n.zoneFrom(zone.label, n(from)),
        (null, null) => zone.label,
      });
      from = to;
    }
    return [
      const SizedBox(height: 12),
      ScaleBar(
        height: 8,
        joined: true,
        bands: bands,
        marker: value == null ? null : scaleFraction(scale, value),
        markerColor: context.textColor,
        markerSize: 16,
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final label in labels)
            Flexible(
              child: Text(label, style: TextStyle(fontSize: 10, color: tokens.muted)),
            ),
        ],
      ),
    ];
  }
}
