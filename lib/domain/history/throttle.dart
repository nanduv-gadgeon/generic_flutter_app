import 'dart:async';

/// [source]'s first value at once, then at most one value per [every]: the newest one that
/// arrived meanwhile (older ones are dropped). Keeps a screen up to date with a stream that may
/// change every few seconds without redoing its work on every change.
Stream<T> throttleLatest<T>(Stream<T> source, Duration every) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  Timer? timer;
  late T newest;
  var waiting = false;

  void tick() {
    if (waiting) {
      waiting = false;
      out.add(newest);
      timer = Timer(every, tick);
    } else {
      timer = null;
    }
  }

  out = StreamController<T>(
    onListen: () {
      sub = source.listen(
        (value) {
          if (timer == null) {
            out.add(value);
            timer = Timer(every, tick);
          } else {
            newest = value;
            waiting = true;
          }
        },
        onError: out.addError,
        onDone: () {
          // Nothing more will come: pass on what is waiting now, without holding a timer.
          timer?.cancel();
          timer = null;
          if (waiting) out.add(newest);
          unawaited(out.close());
        },
      );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () {
      timer?.cancel();
      return sub?.cancel();
    },
  );
  return out.stream;
}
