import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../domain/alerts/alert_category.dart';
import '../../l10n/l10n.dart';
import '../strings/alert_strings.dart';

/// The row of filters over the Alerts list (mockup v2.1): All, then one per [AlertCategory]. It
/// scrolls sideways when it does not fit. The picked one is filled and announced as selected.
class AlertFilterChips extends StatelessWidget {
  const AlertFilterChips({super.key, required this.selected, required this.onSelected});

  /// Null is "All".
  final AlertCategory? selected;
  final ValueChanged<AlertCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.l10n.alertsFilterLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, category) in <AlertCategory?>[null, ...AlertCategory.values].indexed)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: _Chip(
                  label: context.l10n.alertFilter(category),
                  selected: category == selected,
                  onTap: () => onSelected(category),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : tokens.chipBg,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // 32 px as in the mockup; the touch target grows with the text.
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimary : tokens.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
