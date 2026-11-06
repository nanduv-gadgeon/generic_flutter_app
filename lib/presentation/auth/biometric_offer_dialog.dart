import 'package:flutter/material.dart';

import '../../domain/services/biometric_auth.dart';
import '../strings/auth_strings.dart';

/// Asks once, after the first password login, whether to use biometrics next time.
Future<bool> showBiometricOfferDialog(BuildContext context, BiometricKind kind) async {
  final name = biometricName(kind);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AuthStrings.biometricOfferTitle(name)),
      content: const Text(AuthStrings.biometricOfferBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AuthStrings.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AuthStrings.turnOn),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// What the phone calls its biometric login.
String biometricName(BiometricKind kind) => switch (kind) {
  BiometricKind.face => AuthStrings.faceId,
  BiometricKind.fingerprint => AuthStrings.fingerprint,
  BiometricKind.other => AuthStrings.biometrics,
};
