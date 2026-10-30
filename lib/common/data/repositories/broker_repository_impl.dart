import 'package:http/http.dart' as http;

import '../../domain/entities/broker_account.dart';
import '../../domain/entities/execution_result.dart';
import '../../domain/entities/trade_plan.dart';
import '../../domain/entities/trade_signal.dart';
import '../../domain/repositories/broker_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/remote/broker_api.dart';
import '../datasources/remote/groww_api.dart';
import '../datasources/remote/upstox_api.dart';
import '../datasources/remote/zerodha_api.dart';

/// Routes each call to the API of the account's broker, applying the web
/// CORS proxy from settings.
class BrokerRepositoryImpl implements BrokerRepository {
  BrokerRepositoryImpl(this._http, this._settings);

  final http.Client _http;
  final SettingsRepository _settings;

  BrokerApi _api(BrokerAccount account) {
    final proxy = _settings.current.corsProxy;
    return switch (account.broker) {
      BrokerType.zerodha => ZerodhaApi(account, _http, proxy),
      BrokerType.upstox => UpstoxApi(account, _http, proxy),
      BrokerType.groww => GrowwApi(account, _http, proxy),
    };
  }

  @override
  bool get acceptsAccessTokens => true;

  @override
  Future<String> loginUrl(BrokerAccount account) async => _api(account).loginUrl();

  @override
  Future<String> exchangeToken(BrokerAccount account, String redirectUrlOrCode) =>
      _api(account).exchangeToken(redirectUrlOrCode);

  @override
  Future<ResolvedInstrument> resolve(BrokerAccount account, TradeSignal signal) => _api(account).resolve(signal);

  @override
  Future<List<PlacedOrder>> placeTrade(BrokerAccount account, ResolvedInstrument instrument, TradePlan plan) =>
      _api(account).placeTrade(instrument, plan);
}
