/// Outcome of a forgot-password reset (Phase 1: confirmed with the phone's own screen lock).
sealed class ResetResult {
  const ResetResult();
}

/// The new password is saved.
final class ResetSuccess extends ResetResult {
  const ResetSuccess();
}

/// The phone has no PIN, pattern, passcode or biometrics, so the owner cannot be confirmed.
final class NoScreenLock extends ResetResult {
  const NoScreenLock();
}

/// The phone's prompt was cancelled or failed.
final class OwnerNotVerified extends ResetResult {
  const OwnerNotVerified();
}

/// No local account has this email. Only reported after the owner is verified.
final class NoAccountForEmail extends ResetResult {
  const NoAccountForEmail();
}
