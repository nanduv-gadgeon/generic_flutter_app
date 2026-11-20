import 'package:flutter/material.dart';

import '../../domain/services/permission_service.dart';
import '../../l10n/l10n.dart';

/// Turning Notifications off in Profile: only the phone's Settings can turn off this app's
/// notifications, so this says so and offers to open them. When the user comes back, the switch
/// follows what they chose there. Says so when Settings could not be opened.
Future<void> offerNotificationSettings(BuildContext context, PermissionService permissions) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.profileNotificationsOffTitle),
      content: Text(l10n.profileNotificationsOffBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.permissionOpenSettings),
        ),
      ],
    ),
  );
  if (open != true) return;
  if (!await permissions.openSettings()) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileNotificationsSettingsFailed)));
  }
}
