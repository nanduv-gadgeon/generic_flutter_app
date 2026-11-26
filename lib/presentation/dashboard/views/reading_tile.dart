import 'package:flutter/material.dart';

import '../../../domain/dashboard/reading_status.dart';
import '../../../domain/models/reading.dart';
import '../../widgets/device_icons.dart';
import '../../widgets/text_fit.dart';
import '../dashboard_format.dart';
import 'parts/dash_card.dart';
import 'parts/scale_bar.dart';

/// One reading in the "All readings" grid. Which bar and footer it has follows the reading:
/// - normal range: a range bar with the value's marker, "Normal a–b" and the status word;
/// - goal: progress towards it and "65% of goal";
/// - from today's events: "Today";
/// - no value while live: "–" and "No signal".
class ReadingTile extends StatelessWidget {
  const ReadingTile({
    super.key,
    required this.reading,
    required this.value,
    this.pairValue,
    this.live = false,
  });

  final Reading reading;
  final double? value;

  /// The [Reading.pair] reading's value, shown as "a/b".
  final double? pairValue;
  final bool live;

  static const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const footerStyle = TextStyle(fontSize: 11);
  static const _valueSize = 24.0;
  static const _padding = 12.0;

  /// The space the round icon and the gap after it take from the label.
  static const _iconSpace = 38.0;

  /// Whether the tile's label, value and footer each fit on one line in a tile [width] wide; when
  /// they do not, [TilesView] shows one tile per row.
  bool fitsWidth(BuildContext context, double width) {
    final l10n = context.l10n;
    final value = this.value;
    final status = statusOf(reading, value, live: live);
    final text = value == null ? l10n.noValue : l10n.value(reading, value, pairValue: pairValue);
    final inner = width - 2 * _padding;
    const valueStyle = TextStyle(fontSize: _valueSize, fontWeight: FontWeight.w800);
    return fitsOnOneLine(context, [reading.label], labelStyle, inner - _iconSpace) &&
        fitsOnOneLine(context, ['$text ${reading.unit}'], valueStyle, inner) &&
        fitsOnOneLine(
          context,
          ['${l10n.footer(reading, status) ?? ''} ${l10n.statusWord(status) ?? ''}'],
          footerStyle,
          inner,
        );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final value = this.value;
    final status = statusOf(reading, value, live: live);
    final word = l10n.statusWord(status);
    final (statusColor, statusBg) = kindColors(tokens, status.kind);
    final warn = status.isWarning;
    final text = value == null ? null : l10n.value(reading, value, pairValue: pairValue);
    final footer = l10n.footer(reading, status);

    return Semantics(
      container: true,
      label: l10n.spoken(reading.label, text, reading.unit, word),
      excludeSemantics: true,
      child: DashCard(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: warn ? statusBg : tokens.soft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    readingIconFor(reading.icon),
                    size: 16,
                    color: warn ? statusColor : tokens.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reading.label,
                    style: ReadingTile.labelStyle.copyWith(color: tokens.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ValueWithUnit(value: text ?? l10n.noValue, unit: reading.unit, size: _valueSize),
            ...switch (value == null
                ? null
                : _bar(tokens.ok.withAlpha(0x4D), statusColor, status)) {
              // The track is 11 px from the value and the footer; a marker overlaps the gaps.
              final ScaleBar bar? when bar.marker != null => [
                const SizedBox(height: 7),
                bar,
                const SizedBox(height: 7),
              ],
              final ScaleBar bar? => [const SizedBox(height: 11), bar, const SizedBox(height: 11)],
              _ => [const SizedBox(height: 9)],
            },
            // The status word goes under the range when they do not fit side by side.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                Text(footer ?? '', style: ReadingTile.footerStyle.copyWith(color: tokens.muted)),
                if (word != null && status.word != StatusWord.state)
                  Text(
                    word,
                    style: ReadingTile.footerStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// A goal's progress, or the normal range with the value's marker; null for other readings.
  ScaleBar? _bar(Color band, Color marker, ReadingStatus status) {
    if (status.goalFraction case final f?) return ScaleBar(fill: f);
    final scale = scaleOf(reading);
    final normal = reading.normal;
    if (scale == null || normal == null) return null;
    return ScaleBar(
      bands: [
        (
          start: scaleFraction(scale, normal.low),
          end: scaleFraction(scale, normal.high),
          color: band,
        ),
      ],
      marker: scaleFraction(scale, value!),
      markerColor: marker,
    );
  }
}

/// A large value with its unit after it on the same baseline: "72 bpm".
class ValueWithUnit extends StatelessWidget {
  const ValueWithUnit({super.key, required this.value, required this.unit, required this.size});

  final String value;
  final String unit;

  /// Font size of the value; the unit is half of it, at least 12.
  final double size;

  @override
  Widget build(BuildContext context) {
    final unitSize = size >= 48 ? 18.0 : 12.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Wraps rather than being cut off at a large text size.
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: size >= 48 ? -2 : -0.5,
              height: 1.1,
            ),
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            unit,
            style: TextStyle(
              fontSize: unitSize,
              fontWeight: size >= 48 ? FontWeight.w700 : FontWeight.w600,
              color: context.tokens.muted,
            ),
          ),
        ],
      ],
    );
  }
}
