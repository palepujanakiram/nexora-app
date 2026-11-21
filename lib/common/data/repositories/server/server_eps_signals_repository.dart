import '../../../domain/entities/eps_signal.dart';
import '../../../domain/repositories/eps_signals_repository.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/eps_signal_model.dart';

/// Live NIFTY/SENSEX signals, read through nexora-backend's `/signals/feed`
/// route. The vendor's API key lives only on that server — this client never
/// holds it, the same as every other authenticated call this app makes.
class ServerEpsSignalsRepository implements EpsSignalsRepository {
  ServerEpsSignalsRepository(this._api);

  final NexoraServerApi _api;

  @override
  Future<EpsFeed> fetchSignals({
    List<String> symbols = const ['NIFTY', 'SENSEX'],
    List<String> timeframes = const ['15m', '30m', '1H'],
    int history = 5,
  }) async {
    final query = Uri(queryParameters: {
      'symbols': symbols.join(','),
      'tfs': timeframes.join(','),
      'history': '$history',
    }).query;
    final json = await _api.get('/signals/feed?$query');
    return EpsFeedModel.fromJson(json);
  }
}
