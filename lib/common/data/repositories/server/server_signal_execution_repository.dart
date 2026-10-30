import 'package:uuid/uuid.dart';

import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/broker_account.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../domain/repositories/account_repository.dart';
import '../../../domain/repositories/signal_execution_repository.dart';
import '../../../domain/services/trade_pricing.dart';
import '../../../error/exceptions.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/server_order_model.dart';

/// Places a signal through the nexora-backend server, which sends a LIMIT
/// entry to each account from its static IP and tracks every leg.
///
/// The server's quantity is the same on every account of an order, so the
/// accounts are grouped by lots and product, one order per group. Each order
/// carries its own `Idempotency-Key`, so a retry can't place it twice.
class ServerSignalExecutionRepository implements SignalExecutionRepository {
  ServerSignalExecutionRepository(this._api, this._accounts, {String Function()? newKey})
    : _newKey = newKey ?? (() => const Uuid().v4());

  final NexoraServerApi _api;
  final AccountRepository _accounts;
  final String Function() _newKey;

  @override
  Future<List<ExecutionResult>> execute(TradeSignal signal, Set<String> accountIds, AppSettings settings) async {
    final accounts = _accounts.current.where((a) => accountIds.contains(a.id)).toList();
    final byId = {for (final a in accounts) a.id: a};
    final _Contract contract;
    try {
      contract = await _contract(signal);
    } on ServerApiException catch (e) {
      return [for (final a in accounts) _failed(a, signal, e.message, e.code)];
    }
    final price = TradePricing.roundToTick(TradePricing.entryPrice(signal, settings.entryPriceMode), contract.tickSize);

    final groups = <(int, ProductType), List<BrokerAccount>>{};
    for (final a in accounts) {
      groups.putIfAbsent((a.lots, a.product), () => []).add(a);
    }
    final results = await Future.wait(
      groups.entries.map((g) async {
        final (lots, product) = g.key;
        try {
          final json = await _api.post('/orders', {
            'instrumentId': contract.id,
            'side': signal.side,
            'quantity': lots * contract.lotSize,
            'orderType': 'LIMIT',
            'product': ServerOrderModel.product(product),
            'price': ServerOrderModel.rupees(price),
            'referencePrice': ServerOrderModel.rupees(price),
            'accountIds': [for (final a in g.value) a.id],
          }, _newKey());
          final time = DateTime.now();
          return [
            for (final leg in (json['legs'] as List).cast<Map<String, dynamic>>())
              ServerOrderModel.fromLeg(
                leg,
                order: {...json, 'instrumentId': contract.id, 'side': signal.side},
                accounts: byId,
                time: time,
                signalText: signal.raw,
              ),
          ];
        } on ServerApiException catch (e) {
          // Refused before reaching any broker (risk check, plan, kill switch…).
          return [for (final a in g.value) _failed(a, signal, e.message, e.code)];
        }
      }),
    );
    return results.expand((r) => r).toList();
  }

  /// The server's instrument id, lot size and tick size for the signal.
  Future<_Contract> _contract(TradeSignal signal) async {
    final parsed = await _api.post('/signals/parse', {'text': signal.raw});
    final id = parsed['instrumentId'] as String?;
    if (id == null) {
      throw ServerApiException('The server doesn\'t list ${signal.contractLabel} yet. Check the expiry and strike.');
    }
    final query = Uri(
      queryParameters: {
        'underlying': signal.underlying,
        'type': signal.optionCode,
        'expiry': signal.expiryIso,
        'exchange': signal.exchange,
        'limit': '500',
      },
    ).query;
    final list = await _api.get('/instruments?$query');
    final match = (list['instruments'] as List).cast<Map<String, dynamic>>().where((i) => i['id'] == id).firstOrNull;
    if (match == null) throw ServerApiException('The server doesn\'t list ${signal.contractLabel} yet.');
    return _Contract(id, match['lotSize'] as int, double.parse('${match['tickSize'] ?? '0.05'}'));
  }

  ExecutionResult _failed(BrokerAccount a, TradeSignal signal, String message, String? code) => ExecutionResult(
    accountLabel: a.label,
    broker: a.broker.label,
    signalText: signal.raw,
    paper: a.paperMode,
    time: DateTime.now(),
    symbol: signal.contractLabel,
    error: message,
    accountId: a.id,
    errorCode: code,
  );
}

class _Contract {
  const _Contract(this.id, this.lotSize, this.tickSize);
  final String id;
  final int lotSize;
  final double tickSize;
}
