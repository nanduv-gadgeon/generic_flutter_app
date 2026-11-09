import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../domain/services/biometric_auth.dart';

/// Face ID / fingerprint through the `local_auth` plugin, plus enrolment tracking through the app's
/// own channel (`BiometricEnrollment` in MainActivity / AppDelegate).
class LocalBiometricAuth implements BiometricAuth {
  LocalBiometricAuth([LocalAuthentication? auth, MethodChannel? enrollment])
    : _auth = auth ?? LocalAuthentication(),
      _enrollment = enrollment ?? const MethodChannel('app/biometric_enrollment');

  final LocalAuthentication _auth;
  final MethodChannel _enrollment;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> canVerifyOwner() async {
    try {
      // False on Android and iOS when no PIN, pattern, passcode or biometric is set up.
      return await _auth.isDeviceSupported();
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

  @override
  Future<bool> rememberEnrollment() async {
    try {
      return await _enrollment.invokeMethod<bool>('remember') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> enrollmentChanged() async {
    try {
      return await _enrollment.invokeMethod<bool>('changed') ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<void> forgetEnrollment() async {
    try {
      await _enrollment.invokeMethod<void>('forget');
    } on PlatformException {
      // Nothing saved.
    } on MissingPluginException {
      // Nothing saved.
    }
  }
}
