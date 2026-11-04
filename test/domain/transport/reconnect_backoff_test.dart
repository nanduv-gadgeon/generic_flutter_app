import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/transport/reconnect_backoff.dart';

void main() {
  const backoff = ReconnectBackoff();
  final cases = {0: 2, 1: 5, 2: 15, 3: 60, 4: 60, 50: 60, -1: 2};
  for (final MapEntry(key: attempt, value: seconds) in cases.entries) {
    test('attempt $attempt waits $seconds s', () {
      expect(backoff.delayFor(attempt), Duration(seconds: seconds));
    });
  }
}
