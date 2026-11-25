import 'package:flutter/material.dart';

import '../../../domain/models/reading.dart';
import '../../widgets/fit_grid.dart';
import '../dashboard_format.dart';
import 'parts/section_title.dart';
import 'reading_tile.dart';

/// "All readings" and a two-column grid of [ReadingTile]s; tiles in a row share its height. With
/// large text, when a tile's texts would not fit half the width, each tile gets a row of its own.
class TilesView extends StatelessWidget {
  const TilesView({
    super.key,
    required this.readings,
    required this.values,
    required this.count,
    this.live = false,
    bool? missingIsNoSignal,
  }) : missingIsNoSignal = missingIsNoSignal ?? live;

  final List<Reading> readings;
  final Map<String, double> values;

  /// How many values the dashboard shows, the main card's included ("7 values · live").
  final int count;
  final bool live;

  /// A tile with no value shows "No signal" (default: while [live]).
  final bool missingIsNoSignal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ReadingTile tile(Reading r) => ReadingTile(
      reading: r,
      value: values[r.key],
      pairValue: r.pair == null ? null : values[r.pair],
      live: missingIsNoSignal,
    );
    final tiles = [for (final r in readings) tile(r)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          l10n.allReadings,
          trailing: live ? l10n.valuesLive(count) : l10n.valuesCount(count),
        ),
        FitGrid(
          top: 10,
          fits: (context, width) => tiles.every((t) => t.fitsWidth(context, width)),
          children: tiles,
        ),
      ],
    );
  }
}
