import 'package:flutter/material.dart';

import '../../domain/services/biometric_auth.dart';
import '../../l10n/l10n.dart';

/// Asks once, after the first password login, whether to use biometrics next time.
Future<bool> showBiometricOfferDialog(BuildContext context, BiometricKind kind) async {
  final name = biometricName(context.l10n, kind);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.authBiometricOfferTitle(name)),
      content: Text(context.l10n.authBiometricOfferBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.authNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.authTurnOn),
        ),
      ],
    ),
  );
  return accepted ?? false;
}

/// What the phone calls its biometric login.
String biometricName(AppLocalizations l10n, BiometricKind kind) => switch (kind) {
  BiometricKind.face => l10n.authFaceId,
  BiometricKind.fingerprint => l10n.authFingerprint,
  BiometricKind.other => l10n.authBiometrics,
};
