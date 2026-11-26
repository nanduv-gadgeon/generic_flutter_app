import 'package:flutter/material.dart';

import '../dashboard/dashboard_format.dart';
import 'text_fit.dart';

/// Two or more tabs side by side in a grey track; the selected one is a raised white segment
/// (mockup: Live / History on a device, By day / 7-day summary on History). With large text, when a
/// label would not fit its share of the row, the tabs stack, one full-width row each.
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;

  /// Index of the selected tab.
  final int selected;
  final ValueChanged<int> onChanged;

  static const _labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static const _tabPadding = 6.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final inner = (tokens.radiusSmall - 4).clamp(4.0, tokens.radiusSmall);
    Widget tab(int index) {
      final on = index == selected;
      return Semantics(
        button: true,
        selected: on,
        label: labels[index],
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: _tabPadding, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? tokens.surface : null,
              borderRadius: BorderRadius.circular(inner),
              boxShadow: on
                  ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))]
                  : null,
            ),
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              style: _labelStyle.copyWith(color: on ? context.textColor : tokens.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.chipBg,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final share = (constraints.maxWidth - _gap * (labels.length - 1)) / labels.length;
          if (!fitsOnOneLine(context, labels, _labelStyle, share - 2 * _tabPadding)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(height: _gap),
                  tab(i),
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: tab(i)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
