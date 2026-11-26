import 'package:flutter/material.dart';

import '../../widgets/fit_grid.dart';
import '../../widgets/text_fit.dart';
import '../dashboard_format.dart';
import 'parts/dash_card.dart';

/// Which of the device's numbered channels are on (mockup screen 19, "Enabled channels"): the
/// title and "2 of 7 on", a line of text, then a two-column grid of Channel 1…[count], ticked when
/// on. Shown only: the app sets the channels itself, so nothing here can be tapped.
class ChannelsView extends StatelessWidget {
  const ChannelsView({
    super.key,
    required this.title,
    this.text,
    required this.count,
    required this.enabled,
  });

  final String title;

  /// The line under the title, from the config.
  final String? text;

  /// How many channels the device has, numbered from 1.
  final int count;

  /// The channels that are on.
  final Set<int> enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final on = [for (var n = 1; n <= count; n++) n].where(enabled.contains).length;
    final summary = l10n.dashboardChannelsOn(on, count);
    final text = this.text;
    final options = [
      for (var n = 1; n <= count; n++)
        _Channel(label: l10n.dashboardChannel(n), on: enabled.contains(n)),
    ];

    return DashCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: l10n.dashboardChannelsSpoken(title, on, count),
            excludeSemantics: true,
            // "2 of 7 on" goes under the title when they do not fit side by side.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  summary,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tokens.accent),
                ),
              ],
            ),
          ),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text, style: TextStyle(fontSize: 12, height: 1.4, color: tokens.muted)),
          ],
          FitGrid(
            top: 10,
            gap: 8,
            fits: (context, width) => fitsOnOneLine(
              context,
              [for (final o in options) o.label],
              _Channel.labelStyle,
              width - _Channel.chrome,
            ),
            children: options,
          ),
        ],
      ),
    );
  }
}

/// One channel: a box (ticked when on) and its name. Not a button: it only shows the state.
class _Channel extends StatelessWidget {
  const _Channel({required this.label, required this.on});

  final String label;
  final bool on;

  static const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

  /// The width the padding, border, tick box and gap take from the label.
  static const chrome = 2 * 12 + 2 * 1.5 + 18 + 8;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: label,
      checked: on,
      enabled: false, // Read-only: the app sets the channels.
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? tokens.soft : tokens.surface,
          border: Border.all(color: on ? tokens.accent : tokens.border, width: 1.5),
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: on ? tokens.accent : null,
                border: Border.all(color: on ? tokens.accent : tokens.border, width: 2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: on ? Icon(Icons.check, size: 12, color: tokens.surface) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: labelStyle.copyWith(color: on ? tokens.accent : tokens.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
