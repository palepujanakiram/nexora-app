import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/entities/broker_account.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_plan.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../error/exceptions.dart';
import 'broker_api.dart';

/// Upstox API v2/v3. Docs: https://upstox.com/developer/api-documentation/
class UpstoxApi with BrokerHttp implements BrokerApi {
  UpstoxApi(this.account, this._http, this.corsProxy);

  static const _base = 'https://api.upstox.com';
  static const _hft = 'https://api-hft.upstox.com';

  /// Option-chain lookups need the underlying's instrument key. Stock options
  /// need ISIN-based keys and are not mapped yet.
  static const underlyingKeys = {
    'NIFTY': 'NSE_INDEX|Nifty 50',
    'BANKNIFTY': 'NSE_INDEX|Nifty Bank',
    'FINNIFTY': 'NSE_INDEX|Nifty Fin Service',
    'MIDCPNIFTY': 'NSE_INDEX|NIFTY MID SELECT',
    'SENSEX': 'BSE_INDEX|SENSEX',
    'BANKEX': 'BSE_INDEX|BANKEX',
  };

  final BrokerAccount account;
  final http.Client _http;
  @override
  final String corsProxy;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${account.accessToken}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  @override
  String loginUrl() => Uri.https('api.upstox.com', '/v2/login/authorization/dialog', {
        'response_type': 'code',
        'client_id': account.apiKey,
        'redirect_uri': account.redirectUri,
      }).toString();

  @override
  Future<String> exchangeToken(String redirectUrlOrCode) async {
    final code = BrokerHttp.extractParam(redirectUrlOrCode, 'code');
    final res = await _http.post(
      url('$_base/v2/login/authorization/token'),
      headers: {'Accept': 'application/json'},
      body: {
        'code': code,
        'client_id': account.apiKey,
        'client_secret': account.apiSecret,
        'redirect_uri': account.redirectUri,
        'grant_type': 'authorization_code',
      },
    );
    final body = _decode(res);
    final token = body['access_token'] as String?;
    if (res.statusCode != 200 || token == null) throw BrokerApiException('Upstox: ${_error(body, res)}');
    return token;
  }

  @override
  Future<ResolvedInstrument> resolve(TradeSignal signal) async {
    final underlyingKey = underlyingKeys[signal.underlying];
    if (underlyingKey == null) {
      throw BrokerApiException('Upstox: underlying ${signal.underlying} is not mapped yet (indices only).');
    }
    final uri = url(Uri.https('api.upstox.com', '/v2/option/contract', {
      'instrument_key': underlyingKey,
      'expiry_date': signal.expiryIso,
    }).toString());
    final data = await _data(_http.get(uri, headers: _headers));
    for (final c in (data as List).cast<Map>()) {
      if (c['instrument_type'] == signal.optionCode && (c['strike_price'] as num).toDouble() == signal.strike) {
        return ResolvedInstrument(
          symbol: c['trading_symbol'] as String,
          exchange: signal.exchange,
          lotSize: (c['lot_size'] as num).toInt(),
          instrumentKey: c['instrument_key'] as String,
        );
      }
    }
    throw BrokerApiException('No Upstox contract found for ${signal.contractLabel}.');
  }

  @override
  Future<List<PlacedOrder>> placeTrade(ResolvedInstrument inst, TradePlan plan) async {
    final product = plan.product == ProductType.intraday ? 'I' : 'D';
    if (!plan.hasExits) {
      final data = await _data(_http.post(
        url('$_hft/v3/order/place'),
        headers: _headers,
        body: jsonEncode({
          'quantity': plan.quantity,
          'product': product,
          'validity': 'DAY',
          'price': plan.entryPrice,
          'tag': 'signal',
          'instrument_token': inst.instrumentKey,
          'order_type': 'LIMIT',
          'transaction_type': plan.signal.side,
          'disclosed_quantity': 0,
          'trigger_price': 0,
          'is_amo': false,
          'slice': true,
        }),
      ));
      final ids = ((data as Map)['order_ids'] as List).cast<Object>();
      return [for (final id in ids) PlacedOrder('ENTRY', '$id')];
    }

    // A "MULTIPLE" GTT bundles entry, target and stop loss; Upstox places the
    // exit legs only after the entry fills.
    final ltp = await _ltp(inst).catchError((_) => plan.entryPrice);
    final buy = plan.signal.isBuy;
    final entryTrigger = buy
        ? (ltp > plan.entryPrice ? 'BELOW' : 'IMMEDIATE')
        : (ltp < plan.entryPrice ? 'ABOVE' : 'IMMEDIATE');
    final data = await _data(_http.post(
      url('$_base/v3/order/gtt/place'),
      headers: _headers,
      body: jsonEncode({
        'type': 'MULTIPLE',
        'quantity': plan.quantity,
        'product': product,
        'instrument_token': inst.instrumentKey,
        'transaction_type': plan.signal.side,
        'rules': [
          {'strategy': 'ENTRY', 'trigger_type': entryTrigger, 'trigger_price': plan.entryPrice},
          {'strategy': 'TARGET', 'trigger_type': 'IMMEDIATE', 'trigger_price': plan.target},
          {'strategy': 'STOPLOSS', 'trigger_type': 'IMMEDIATE', 'trigger_price': plan.stopLoss},
        ],
      }),
    ));
    final ids = ((data as Map)['gtt_order_ids'] as List).cast<Object>();
    return [for (final id in ids) PlacedOrder('GTT entry+SL ${plan.stopLoss}+TGT ${plan.target}', '$id')];
  }

  Future<double> _ltp(ResolvedInstrument inst) async {
    final uri = url(Uri.https('api.upstox.com', '/v2/market-quote/ltp', {'instrument_key': inst.instrumentKey}).toString());
    final data = await _data(_http.get(uri, headers: _headers)) as Map;
    return ((data.values.first as Map)['last_price'] as num).toDouble();
  }

  Future<Object?> _data(Future<http.Response> request) async {
    final res = await request;
    final body = _decode(res);
    if (res.statusCode != 200 || body['status'] != 'success') {
      throw BrokerApiException('Upstox: ${_error(body, res)}');
    }
    return body['data'];
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw BrokerApiException('Upstox returned HTTP ${res.statusCode}.');
    }
  }

  static String _error(Map<String, dynamic> body, http.Response res) {
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) return '${(errors.first as Map)['message']}';
    return 'HTTP ${res.statusCode}';
  }
}
