import 'package:flutter/material.dart';

import '../strings/add_device_strings.dart';
import '../strings/common_strings.dart';

/// Asks "Remove [name]?" before a device already added is deleted from the phone. True when the
/// user confirms.
Future<bool> confirmRemoveDevice(BuildContext context, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AddDeviceStrings.removeTitle(name)),
      content: const Text(AddDeviceStrings.removeBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(CommonStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AddDeviceStrings.remove),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
