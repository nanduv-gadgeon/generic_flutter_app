import 'package:local_auth/local_auth.dart';

import '../../domain/services/biometric_auth.dart';

/// Face ID / fingerprint through the `local_auth` plugin.
class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<BiometricKind> kind() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) return BiometricKind.fingerprint;
    } on LocalAuthException {
      // Fall through to a neutral label.
    }
    return BiometricKind.other;
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // The device passcode is allowed as a fallback.
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on LocalAuthException {
      return false;
    }
  }
}
