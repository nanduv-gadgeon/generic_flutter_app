/// Failed-login lock-out for Phase 1 local accounts (docs/decisions.md, 2026-11-06).
///
/// After [maxFailedLogins] wrong passwords in a row the account is locked for [lockoutDuration].
/// While locked the password is not checked, so the right one does not get in either.
library;

const maxFailedLogins = 5;
const lockoutDuration = Duration(seconds: 30);

/// An account's failed-login state, as stored with the user.
typedef LockState = ({int failedCount, DateTime? lockedUntil});

/// True while a lock is in force.
bool isLocked(DateTime? lockedUntil, DateTime now) =>
    lockedUntil != null && now.isBefore(lockedUntil);

/// The state after one more wrong password (only called when not locked). The failure that
/// reaches [maxFailedLogins] locks the account and starts the count again from 0.
LockState afterFailedLogin(LockState state, DateTime now) {
  final count = state.failedCount + 1;
  if (count >= maxFailedLogins) return (failedCount: 0, lockedUntil: now.add(lockoutDuration));
  return (failedCount: count, lockedUntil: null);
}
