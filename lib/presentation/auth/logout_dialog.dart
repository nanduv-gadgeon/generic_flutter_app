import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Asks "Log out?" before ending the session. True when the user confirms. Used on the home
/// placeholder now and on Profile (task 1.1.11).
Future<bool> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.authLogOutTitle),
      content: Text(context.l10n.authLogOutBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.commonLogOut),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
