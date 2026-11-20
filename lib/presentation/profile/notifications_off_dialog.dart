import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Asks "Turn off notifications?" before Profile's switch turns them off. True when the user
/// confirms.
Future<bool> confirmNotificationsOff(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.profileNotificationsOffTitle),
        content: Text(l10n.profileNotificationsOffBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.profileNotificationsTurnOff),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
