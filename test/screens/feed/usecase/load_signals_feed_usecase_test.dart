import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';
import 'package:nexora_app/screens/feed/usecase/load_signals_feed_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('delegates to the repository with its defaults', () async {
    final repo = FakeEpsSignalsRepository()
      ..toReturn = const EpsFeed(symbols: [EpsSymbolSignals(symbol: 'NIFTY')]);
    final useCase = LoadSignalsFeedUseCase(repo);

    final feed = await useCase();

    expect(feed.symbols.single.symbol, 'NIFTY');
    expect(repo.calls, 1);
  });

  test('propagates a failure from the repository', () async {
    final repo = FakeEpsSignalsRepository()..toReturn = Exception('down');
    await expectLater(LoadSignalsFeedUseCase(repo)(), throwsException);
  });
}
