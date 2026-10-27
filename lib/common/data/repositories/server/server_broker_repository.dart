import '../../../domain/entities/broker_account.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_plan.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../domain/repositories/broker_repository.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/server_account_model.dart';
import 'server_account_repository.dart';

/// Broker logins through the nexora-backend server: the server holds the API
/// secret and exchanges the redirect for the day's token from its static IP.
/// Orders go through [SignalExecutionRepository], never through here.
class ServerBrokerRepository implements BrokerRepository {
  ServerBrokerRepository(this._api, this._accounts);

  final NexoraServerApi _api;
  final ServerAccountRepository _accounts;

  @override
  bool get acceptsAccessTokens => false;

  @override
  String loginUrl(BrokerAccount account) => _accounts.loginUrlFor(account.id);

  /// Creates the session on the server and returns a placeholder token: the
  /// real one never leaves the server.
  @override
  Future<String> exchangeToken(BrokerAccount account, String redirectUrlOrCode) async {
    final json = await _api.post('/v1/accounts/${account.id}/session', {'input': redirectUrlOrCode});
    _accounts.putFromServer(json);
    return ServerAccountModel.serverToken;
  }

  @override
  Future<ResolvedInstrument> resolve(BrokerAccount account, TradeSignal signal) =>
      throw UnsupportedError('The server resolves contracts when it places a signal.');

  @override
  Future<List<PlacedOrder>> placeTrade(BrokerAccount account, ResolvedInstrument instrument, TradePlan plan) =>
      throw UnsupportedError('The server places orders; use SignalExecutionRepository.');
}
