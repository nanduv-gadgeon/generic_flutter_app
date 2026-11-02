import 'package:flutter/material.dart';

import '../../domain/services/biometric_auth.dart';

/// Asks once, after the first password login, whether to use biometrics next time.
Future<bool> showBiometricOfferDialog(BuildContext context, BiometricKind kind) async {
  final name = biometricName(kind);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Use $name to log in next time?'),
      content: const Text('You can turn this off later in your profile.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Turn on')),
      ],
    ),
  );
  return accepted ?? false;
}

/// What the phone calls its biometric login.
String biometricName(BiometricKind kind) => switch (kind) {
  BiometricKind.face => 'Face ID',
  BiometricKind.fingerprint => 'fingerprint',
  BiometricKind.other => 'biometrics',
};
