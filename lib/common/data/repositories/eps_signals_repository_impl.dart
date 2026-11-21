import '../../domain/entities/eps_signal.dart';
import '../../domain/repositories/eps_signals_repository.dart';
import '../datasources/remote/eps_signals_api.dart';
import '../models/eps_signal_model.dart';

class EpsSignalsRepositoryImpl implements EpsSignalsRepository {
  EpsSignalsRepositoryImpl(this._api);

  final EpsSignalsApi _api;

  @override
  Future<EpsFeed> fetchSignals({
    List<String> symbols = const ['NIFTY', 'SENSEX'],
    List<String> timeframes = const ['15m', '30m', '1H'],
    int history = 5,
  }) async {
    final json = await _api.fetchSignals(symbols: symbols, timeframes: timeframes, history: history);
    return EpsFeedModel.fromJson(json);
  }
}
