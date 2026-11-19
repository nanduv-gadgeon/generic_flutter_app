import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/history/throttle.dart';

/// Today's History chart updates at most every 5 s while readings are stored every 2 s.
void main() {
  const every = Duration(seconds: 5);

  test('the first value at once; a burst gives only its newest, at the end of the 5 s', () {
    fakeAsync((time) {
      final source = StreamController<int>();
      final seen = <int>[];
      throttleLatest(source.stream, every).listen(seen.add);

      source.add(1);
      time.flushMicrotasks();
      expect(seen, [1]);

      for (final v in [2, 3, 4]) {
        time.elapse(const Duration(seconds: 1));
        source.add(v);
      }
      time.elapse(const Duration(seconds: 1));
      expect(seen, [1], reason: 'still within the 5 s');

      time.elapse(const Duration(seconds: 1));
      expect(seen, [1, 4]);
      unawaited(source.close());
    });
  });

  test('after a quiet 5 s the next value shows at once', () {
    fakeAsync((time) {
      final source = StreamController<int>();
      final seen = <int>[];
      throttleLatest(source.stream, every).listen(seen.add);

      source.add(1);
      time.elapse(const Duration(seconds: 12));
      source.add(2);
      time.flushMicrotasks();

      expect(seen, [1, 2]);
      unawaited(source.close());
    });
  });

  test(
    'when the source ends, what is waiting is passed on at once, without waiting out the 5 s',
    () async {
      final source = StreamController<int>()
        ..add(1)
        ..add(2);
      unawaited(source.close());

      // Real time: a throttle still holding its 5 s timer would miss this 1 s limit.
      final seen = await throttleLatest(
        source.stream,
        every,
      ).toList().timeout(const Duration(seconds: 1));

      expect(seen, [1, 2]);
    },
  );

  test('cancelling stops the timer and the source', () {
    fakeAsync((time) {
      var cancelled = false;
      final source = StreamController<int>(onCancel: () => cancelled = true);
      final sub = throttleLatest(source.stream, every).listen((_) {});

      source.add(1);
      time.flushMicrotasks();
      unawaited(sub.cancel());
      time.flushMicrotasks();

      expect(cancelled, isTrue);
      expect(time.pendingTimers, isEmpty);
    });
  });
}
