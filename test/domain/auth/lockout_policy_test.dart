import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/auth/lockout_policy.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);

  test('the policy is 5 attempts and a 30 second lock', () {
    expect(maxFailedLogins, 5);
    expect(lockoutDuration, const Duration(seconds: 30));
  });

  // failed count before -> state after one more wrong password
  final failures = <int, LockState>{
    0: (failedCount: 1, lockedUntil: null),
    3: (failedCount: 4, lockedUntil: null),
    4: (failedCount: 0, lockedUntil: now.add(lockoutDuration)), // the 5th locks
  };
  for (final MapEntry(key: before, value: after) in failures.entries) {
    test('afterFailedLogin: $before earlier failures -> $after', () {
      expect(afterFailedLogin((failedCount: before, lockedUntil: null), now), after);
    });
  }

  test('afterFailedLogin: the first failure after a lock ends starts counting again', () {
    final expired = (failedCount: 0, lockedUntil: now.subtract(const Duration(seconds: 1)));
    expect(afterFailedLogin(expired, now), (failedCount: 1, lockedUntil: null));
  });

  // lockedUntil relative to now (null = never locked) -> locked
  final locks = <Duration?, bool>{
    null: false,
    const Duration(seconds: 1): true,
    Duration.zero: false, // ends exactly now
    const Duration(seconds: -1): false,
  };
  for (final MapEntry(key: offset, value: locked) in locks.entries) {
    test('isLocked: until now + $offset -> $locked', () {
      expect(isLocked(offset == null ? null : now.add(offset), now), locked);
    });
  }
}
