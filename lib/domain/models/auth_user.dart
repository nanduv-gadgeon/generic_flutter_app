import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// The logged-in person, as screens see them. Never holds the password hash or salt.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    required int id,
    required String name,
    required String email,

    /// As stored, e.g. `+91 9876543210` (see `fullMobileNumber`).
    required String mobile,
    required bool biometricEnabled,

    /// The profile photo on the phone; null shows initials.
    String? photoPath,
  }) = _AuthUser;
}

/// What the registration screen collects (task 1.1.8).
@freezed
abstract class RegistrationData with _$RegistrationData {
  const factory RegistrationData({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required bool termsAccepted,
  }) = _RegistrationData;
}
