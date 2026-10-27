import 'dart:async';

/// In-memory value that repositories expose as a stream, so every screen
/// sees changes made by any other screen.
class ReactiveCache<T> {
  ReactiveCache(this._value);

  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;

  set value(T next) {
    _value = next;
    _controller.add(next);
  }

  /// Emits the current value first, then every change.
  Stream<T> watch() async* {
    yield _value;
    yield* _controller.stream;
  }
}
