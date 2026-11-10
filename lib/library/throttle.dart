import 'dart:async';

/// Passes the first event, then at most one per [gap], always ending on the
/// latest. Lookups write to the library about once a second, and rebuilding the
/// song list for each write makes scrolling stutter.
Stream<T> throttled<T>(Stream<T> source, Duration gap) {
  StreamSubscription<T>? sub;
  Timer? timer;
  late StreamController<T> out;
  T? pending;
  var hasPending = false;

  void emit(T value) {
    out.add(value);
    timer = Timer(gap, () {
      timer = null;
      if (hasPending) {
        hasPending = false;
        emit(pending as T);
      }
    });
  }

  out = StreamController<T>(
    onListen: () {
      sub = source.listen(
        (value) {
          if (timer == null) {
            emit(value);
          } else {
            pending = value;
            hasPending = true;
          }
        },
        onError: out.addError,
        onDone: out.close,
      );
    },
    onCancel: () {
      timer?.cancel();
      return sub?.cancel();
    },
  );
  return out.stream;
}
