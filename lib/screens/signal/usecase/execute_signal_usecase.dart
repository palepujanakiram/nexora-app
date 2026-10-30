import 'dart:math';

import '../../../common/domain/entities/app_settings.dart';
import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/entities/execution_result.dart';
import '../../../common/domain/entities/trade_plan.dart';
import '../../../common/domain/entities/trade_signal.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../../common/domain/repositories/activity_repository.dart';
import '../../../common/domain/repositories/broker_repository.dart';
import '../../../common/domain/repositories/settings_repository.dart';
import '../../../common/domain/repositories/signal_execution_repository.dart';
import '../../../common/domain/services/trade_pricing.dart';
import '../../../common/error/exceptions.dart';

/// Places a signal on the given accounts in parallel and records the results
/// in the activity log. Per-account failures are returned, not thrown.
///
/// When connected to a nexora-backend server ([remote]), the server places
/// the orders from its static IP and this only shows its results.
class ExecuteSignalUseCase {
  ExecuteSignalUseCase(this._brokers, this._accounts, this._settings, this._activity, {this.remote});

  final BrokerRepository _brokers;
  final AccountRepository _accounts;
  final SettingsRepository _settings;
  final ActivityRepository _activity;

  /// Set while connected to a nexora-backend server.
  final SignalExecutionRepository? remote;
  final _random = Random();

  /// Whether stop loss and target orders are placed with the entry. The
  /// server places the entry only.
  bool get placesExits => remote == null;

  Future<List<ExecutionResult>> call(TradeSignal signal, Set<String> accountIds) async {
    final settings = _settings.current;
    final remote = this.remote;
    final List<ExecutionResult> results;
    if (remote != null) {
      results = await remote.execute(signal, accountIds, settings);
    } else {
      final targets = _accounts.current.where((a) => accountIds.contains(a.id));
      results = await Future.wait(targets.map((a) => _executeOne(a, signal, settings)));
    }
    await _activity.addAll(results);
    return results;
  }

  Future<ExecutionResult> _executeOne(BrokerAccount account, TradeSignal signal, AppSettings settings) async {
    ResolvedInstrument? inst;
    double? price;
    int? qty;
    try {
      // Paper accounts still resolve the real contract when logged in, so the
      // dry run shows the exact symbol and lot size.
      if (account.hasValidToken) {
        inst = await _brokers.resolve(account, signal);
      } else if (!account.paperMode) {
        throw BrokerApiException('Session expired — log in to ${account.label} first.');
      }

      price = TradePricing.roundToTick(
          TradePricing.entryPrice(signal, settings.entryPriceMode), inst?.tickSize ?? 0.05);
      qty = account.lots * (inst?.lotSize ?? 1);
      final withExits = settings.exitMode == ExitMode.withStopAndTarget;
      final plan = TradePlan(
        signal: signal,
        quantity: qty,
        entryPrice: price,
        product: account.product,
        stopLoss: withExits ? signal.stopLoss : null,
        target: withExits ? TradePricing.targetFor(signal, settings) : null,
      );

      final orders = account.paperMode
          ? [
              // Not `1 << 32`: shifts are 32-bit on the web, so that's 0 there.
              PlacedOrder('ENTRY (paper)', 'PAPER-${_random.nextInt(1000000000)}'),
              if (plan.hasExits) PlacedOrder('SL ${plan.stopLoss} / TGT ${plan.target} (paper)', '-'),
            ]
          : await _brokers.placeTrade(account, inst!, plan);

      return _result(account, signal, inst, qty, price, orders: orders);
    } catch (e) {
      return _result(account, signal, inst, qty, price, error: e.toString());
    }
  }

  ExecutionResult _result(
    BrokerAccount account,
    TradeSignal signal,
    ResolvedInstrument? inst,
    int? qty,
    double? price, {
    List<PlacedOrder> orders = const [],
    String? error,
  }) =>
      ExecutionResult(
        accountLabel: account.label,
        broker: account.broker.label,
        signalText: signal.raw,
        paper: account.paperMode,
        time: DateTime.now(),
        symbol: inst?.symbol ?? signal.contractLabel,
        // Without a resolved contract the lot size (and so the quantity) is unknown.
        quantity: inst == null ? null : qty,
        entryPrice: price,
        orders: orders,
        error: error,
        accountId: account.id,
      );
}
