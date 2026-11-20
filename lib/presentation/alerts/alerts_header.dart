import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// "Alerts" with "Mark all read" (disabled when nothing is unread) and "Clear all" (disabled with
/// no alerts). With large text on a small phone the buttons move under the title.
class AlertsHeader extends StatelessWidget {
  const AlertsHeader({super.key, required this.onMarkAllRead, required this.onClearAll});

  final VoidCallback? onMarkAllRead;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.alertsTitle,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            _HeaderButton(
              label: l10n.alertsMarkAllRead,
              color: tokens?.accent,
              onPressed: onMarkAllRead,
            ),
            _HeaderButton(label: l10n.alertsClearAll, color: tokens?.danger, onPressed: onClearAll),
          ],
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, required this.color, required this.onPressed});

  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          foregroundColor: color,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Asks "Clear all alerts?" before deleting them. True when the user confirms.
Future<bool> confirmClearAlerts(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      final tokens = Theme.of(context).extension<AppTokens>();
      return AlertDialog(
        title: Text(l10n.alertsClearAllTitle),
        content: Text(l10n.alertsClearAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tokens?.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.alertsClearAll),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
