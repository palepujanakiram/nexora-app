import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';
import 'package:nexora_app/screens/feed/usecase/load_signals_feed_usecase.dart';
import 'package:nexora_app/screens/feed/viewmodel/feed_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  test('loads once on construction', () async {
    final repo = FakeEpsSignalsRepository()
      ..toReturn = const EpsFeed(symbols: [EpsSymbolSignals(symbol: 'NIFTY')]);
    final vm = FeedViewModel(LoadSignalsFeedUseCase(repo), ticker: const Stream.empty());
    expect(vm.state.loading, isTrue);

    await pumpEventQueue();

    expect(vm.state.loading, isFalse);
    expect(vm.state.feed!.symbols.single.symbol, 'NIFTY');
    expect(vm.state.error, isNull);
    expect(vm.state.lastUpdated, isNotNull);
    expect(repo.calls, 1);
    vm.dispose();
  });

  test('reports a failure and keeps it until a refresh succeeds', () async {
    final repo = FakeEpsSignalsRepository()..toReturn = Exception('offline');
    final vm = FeedViewModel(LoadSignalsFeedUseCase(repo), ticker: const Stream.empty());
    await pumpEventQueue();
    expect(vm.state.error, 'Exception: offline');
    expect(vm.state.loading, isFalse);

    repo.toReturn = const EpsFeed();
    await vm.refresh();
    expect(vm.state.error, isNull);
    expect(repo.calls, 2);
    vm.dispose();
  });

  test('ticks poll again; stop once disposed', () async {
    final repo = FakeEpsSignalsRepository();
    final ticker = StreamController<void>();
    final vm = FeedViewModel(LoadSignalsFeedUseCase(repo), ticker: ticker.stream);
    await pumpEventQueue();
    expect(repo.calls, 1);

    ticker.add(null);
    await pumpEventQueue();
    expect(repo.calls, 2);

    vm.dispose();
    ticker.add(null);
    await pumpEventQueue();
    expect(repo.calls, 2, reason: 'disposed: no longer listening to the ticker');
    await ticker.close();
  });

  test('notifies listeners on every state change', () async {
    final repo = FakeEpsSignalsRepository();
    final vm = FeedViewModel(LoadSignalsFeedUseCase(repo), ticker: const Stream.empty());
    var notified = 0;
    vm.addListener(() => notified++);
    await pumpEventQueue();
    expect(notified, greaterThanOrEqualTo(1));
    vm.dispose();
  });

  test('a refresh that finishes after dispose is ignored', () async {
    final repo = FakeEpsSignalsRepository()..hold = Completer<void>();
    final vm = FeedViewModel(LoadSignalsFeedUseCase(repo), ticker: const Stream.empty());
    vm.dispose();
    repo.hold!.complete();
    await pumpEventQueue();
    // No exception, and nothing crashed trying to notify a disposed ChangeNotifier.
    expect(repo.calls, 1);
  });

  test('refresh() does nothing once disposed', () async {
    final repo = FakeEpsSignalsRepository();
    final vm = FeedViewModel(LoadSignalsFeedUseCase(repo), ticker: const Stream.empty());
    await pumpEventQueue();
    vm.dispose();
    await vm.refresh();
    expect(repo.calls, 1);
  });
}
