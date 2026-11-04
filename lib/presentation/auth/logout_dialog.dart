import 'package:flutter/material.dart';

import '../strings/auth_strings.dart';
import '../strings/common_strings.dart';

/// Asks "Log out?" before ending the session. True when the user confirms. Used on the home
/// placeholder now and on Profile (task 1.1.11).
Future<bool> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(AuthStrings.logOutTitle),
      content: const Text(AuthStrings.logOutBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(CommonStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(CommonStrings.logOut),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
