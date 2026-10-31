import '../../../domain/entities/broker_account.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_plan.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../domain/repositories/broker_repository.dart';
import '../../../error/exceptions.dart';
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

  /// The broker redirects to the server's `/broker-callback/<broker>`, which
  /// finishes the login.
  @override
  bool get loginFinishesOnServer => true;

  /// Reads the account again (`GET /broker-accounts/:id`) and applies it.
  @override
  Future<bool> checkLoggedIn(BrokerAccount account) async {
    _accounts.putFromServer(await _api.get('/broker-accounts/${account.id}'));
    return _accounts.current.where((a) => a.id == account.id).firstOrNull?.hasValidToken ?? false;
  }

  /// The server's login challenge for today (`GET …/relink`): the broker's
  /// login page, or Groww's API keys page. Paper accounts get none: the
  /// server simulates their orders, so it says why instead.
  @override
  Future<String> loginUrl(BrokerAccount account) async {
    final json = await _api.get('/broker-accounts/${account.id}/relink');
    final url = json['url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    final why = json['message'] as String? ?? 'This account needs no broker login.';
    throw ServerApiException(account.paperMode
        ? '$why To log in to ${account.broker.label}, turn off Paper mode in the account\'s settings.'
        : why);
  }

  /// Finishes the login on the server and returns a placeholder token: the
  /// real one never leaves the server.
  @override
  Future<String> exchangeToken(BrokerAccount account, String redirectUrlOrCode) async {
    final json = await _api.post('/broker-accounts/${account.id}/link', {
      'params': linkParams(account, redirectUrlOrCode),
    });
    _accounts.putFromServer(json);
    return ServerAccountModel.serverToken;
  }

  /// What `POST …/link` expects: the whole redirect URL, or the bare
  /// `request_token` (Kite) / `code` (Upstox), or Groww's optional TOTP.
  static Map<String, String> linkParams(BrokerAccount account, String input) {
    final value = input.trim();
    if (Uri.tryParse(value)?.hasScheme ?? false) return {'url': value};
    return switch (account.broker) {
      BrokerType.zerodha => {'request_token': value},
      BrokerType.upstox => {'code': value},
      BrokerType.groww => value.isEmpty ? {} : {'totp': value},
    };
  }

  @override
  Future<ResolvedInstrument> resolve(BrokerAccount account, TradeSignal signal) =>
      throw UnsupportedError('The server resolves contracts when it places an order.');

  @override
  Future<List<PlacedOrder>> placeTrade(BrokerAccount account, ResolvedInstrument instrument, TradePlan plan) =>
      throw UnsupportedError('The server places orders; use SignalExecutionRepository.');
}
