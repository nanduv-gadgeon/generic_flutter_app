import 'package:flutter/material.dart';

import 'dashboard_format.dart';

/// The Live / History switch under the status strip.
class DashboardTabs extends StatelessWidget {
  const DashboardTabs({super.key, required this.history, required this.onChanged});

  /// Whether History is selected.
  final bool history;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final inner = (tokens.radiusSmall - 4).clamp(4.0, tokens.radiusSmall);
    Widget tab(String label, bool selected, bool value) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? tokens.surface : null,
              borderRadius: BorderRadius.circular(inner),
              boxShadow: selected
                  ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? context.textColor : tokens.muted,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.chipBg,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: Row(
        children: [
          tab(l10n.dashboardLive, !history, false),
          const SizedBox(width: 4),
          tab(l10n.dashboardHistory, history, true),
        ],
      ),
    );
  }
}
