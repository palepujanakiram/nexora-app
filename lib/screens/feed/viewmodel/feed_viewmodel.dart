import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/feed_state.dart';
import '../usecase/load_signals_feed_usecase.dart';

class FeedViewModel extends ChangeNotifier {
  /// Polls once on construction, then on every [ticker] tick. [ticker]
  /// defaults to once a minute — the vendor caches responses for 60 seconds,
  /// so anything faster gains nothing.
  FeedViewModel(this._load, {Stream<void>? ticker}) : _ticker = ticker ?? Stream.periodic(const Duration(minutes: 1)) {
    unawaited(refresh());
    _tickSub = _ticker.listen((_) => refresh());
  }

  final LoadSignalsFeedUseCase _load;
  final Stream<void> _ticker;
  late final StreamSubscription<void> _tickSub;
  bool _disposed = false;

  FeedState _state = const FeedState();
  FeedState get state => _state;

  Future<void> refresh() async {
    if (_disposed) return;
    _setState(_state.copyWith(loading: true));
    try {
      final feed = await _load();
      if (_disposed) return;
      _setState(FeedState(loading: false, feed: feed, lastUpdated: DateTime.now(), error: null));
    } catch (e) {
      if (_disposed) return;
      _setState(_state.copyWith(loading: false, error: '$e'));
    }
  }

  void _setState(FeedState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_tickSub.cancel());
    super.dispose();
  }
}
