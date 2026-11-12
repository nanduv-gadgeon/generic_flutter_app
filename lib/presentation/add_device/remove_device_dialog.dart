import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Asks "Remove [name]?" before a device already added is deleted from the phone. True when the
/// user confirms.
Future<bool> confirmRemoveDevice(BuildContext context, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.addDeviceRemoveTitle(name)),
      content: Text(context.l10n.addDeviceRemoveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.addDeviceRemove),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
