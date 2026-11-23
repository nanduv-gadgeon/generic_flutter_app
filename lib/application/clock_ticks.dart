import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

/// The time from [now] at once, then every [every], for providers like "10 min ago" labels.
///
/// A provider watched only by a screen that is not shown (another tab) is paused, and so is its
/// timer. When the screen is shown again the time is read at once, instead of keeping the old one
/// until the next tick, which made new items look newer than "now" ("Just now").
Stream<DateTime> clockTicks(Ref ref, DateTime Function() now, Duration every) {
  final out = StreamController<DateTime>();
  Timer? timer;
  void start() {
    timer?.cancel();
    if (out.isClosed) return;
    out.add(now());
    timer = Timer.periodic(every, (_) => out.add(now()));
  }

  ref
    ..onResume(start)
    ..onCancel(() => timer?.cancel())
    ..onDispose(() {
      timer?.cancel();
      unawaited(out.close());
    });
  start();
  return out.stream;
}
