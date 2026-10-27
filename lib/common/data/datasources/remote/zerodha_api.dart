import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../domain/entities/broker_account.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_plan.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../domain/services/trade_pricing.dart';
import '../../../error/exceptions.dart';
import 'broker_api.dart';

/// Kite Connect v3. Docs: https://kite.trade/docs/connect/v3/
class ZerodhaApi with BrokerHttp implements BrokerApi {
  ZerodhaApi(this.account, this._http, this.corsProxy);

  static const _base = 'https://api.kite.trade';

  /// Instrument dumps are large (several MB) and change once a day, so they
  /// are cached per exchange per day across all Zerodha accounts.
  static final Map<String, List<Map<String, String>>> _instrumentCache = {};

  final BrokerAccount account;
  final http.Client _http;
  @override
  final String corsProxy;

  Map<String, String> get _headers => {
        'X-Kite-Version': '3',
        'Authorization': 'token ${account.apiKey}:${account.accessToken}',
      };

  @override
  String loginUrl() => 'https://kite.zerodha.com/connect/login?v=3&api_key=${Uri.encodeComponent(account.apiKey)}';

  @override
  Future<String> exchangeToken(String redirectUrlOrCode) async {
    final requestToken = BrokerHttp.extractParam(redirectUrlOrCode, 'request_token');
    final checksum = sha256.convert(utf8.encode('${account.apiKey}$requestToken${account.apiSecret}')).toString();
    final data = await _send(_http.post(
      url('$_base/session/token'),
      headers: {'X-Kite-Version': '3'},
      body: {'api_key': account.apiKey, 'request_token': requestToken, 'checksum': checksum},
    ));
    return data['access_token'] as String;
  }

  @override
  Future<ResolvedInstrument> resolve(TradeSignal signal) async {
    final rows = await _instruments(signal.exchange);
    for (final r in rows) {
      if (r['name'] == signal.underlying &&
          r['instrument_type'] == signal.optionCode &&
          r['expiry'] == signal.expiryIso &&
          double.tryParse(r['strike'] ?? '') == signal.strike) {
        return ResolvedInstrument(
          symbol: r['tradingsymbol']!,
          exchange: r['exchange'] ?? signal.exchange,
          lotSize: int.parse(r['lot_size']!),
          tickSize: double.tryParse(r['tick_size'] ?? '') ?? 0.05,
        );
      }
    }
    throw BrokerApiException('No Kite contract found for ${signal.contractLabel} on ${signal.exchange}.');
  }

  @override
  Future<List<PlacedOrder>> placeTrade(ResolvedInstrument inst, TradePlan plan) async {
    final product = plan.product == ProductType.intraday ? 'MIS' : 'NRML';
    final entry = await _send(_http.post(
      url('$_base/orders/regular'),
      headers: _headers,
      body: {
        'tradingsymbol': inst.symbol,
        'exchange': inst.exchange,
        'transaction_type': plan.signal.side,
        'order_type': 'LIMIT',
        'quantity': '${plan.quantity}',
        'price': plan.entryPrice.toStringAsFixed(2),
        'product': product,
        'validity': 'DAY',
        'tag': 'signal',
      },
    ));
    final orders = [PlacedOrder('ENTRY', '${entry['order_id']}')];
    if (!plan.hasExits) return orders;

    // GTT OCO: whichever of stop loss / target triggers first fires an exit
    // limit order and cancels the other. Kite wants legs in ascending price.
    final exitSide = plan.signal.exitSide;
    final sl = plan.stopLoss!;
    final tgt = plan.target!;
    // Give the stop-loss limit a 5% buffer past the trigger so it fills on a fast move.
    final slLimit = TradePricing.roundToTick(exitSide == 'SELL' ? sl * 0.95 : sl * 1.05, inst.tickSize);
    final legs = [(sl, slLimit), (tgt, tgt)]..sort((a, b) => a.$1.compareTo(b.$1));
    final ltp = await _ltp(inst).catchError((_) => plan.entryPrice);

    final gtt = await _send(_http.post(
      url('$_base/gtt/triggers'),
      headers: _headers,
      body: {
        'type': 'two-leg',
        'condition': jsonEncode({
          'exchange': inst.exchange,
          'tradingsymbol': inst.symbol,
          'trigger_values': legs.map((l) => l.$1).toList(),
          'last_price': ltp,
        }),
        'orders': jsonEncode([
          for (final leg in legs)
            {
              'exchange': inst.exchange,
              'tradingsymbol': inst.symbol,
              'transaction_type': exitSide,
              'quantity': plan.quantity,
              'order_type': 'LIMIT',
              'product': product,
              'price': leg.$2,
            },
        ]),
      },
    ));
    orders.add(PlacedOrder('GTT OCO (SL $sl / TGT $tgt)', '${gtt['trigger_id']}'));
    return orders;
  }

  Future<double> _ltp(ResolvedInstrument inst) async {
    final key = '${inst.exchange}:${inst.symbol}';
    final data = await _send(_http.get(url('$_base/quote/ltp?i=${Uri.encodeQueryComponent(key)}'), headers: _headers));
    return ((data[key] as Map)['last_price'] as num).toDouble();
  }

  Future<List<Map<String, String>>> _instruments(String exchange) async {
    final now = DateTime.now();
    final cacheKey = '$exchange-${now.year}-${now.month}-${now.day}';
    final cached = _instrumentCache[cacheKey];
    if (cached != null) return cached;

    final res = await _http.get(url('$_base/instruments/$exchange'), headers: _headers);
    if (res.statusCode != 200) {
      throw BrokerApiException('Kite instruments download failed (${res.statusCode}). Is the session valid?');
    }
    final lines = const LineSplitter().convert(res.body);
    final header = BrokerHttp.splitCsv(lines.first);
    final rows = [
      for (final line in lines.skip(1))
        if (line.isNotEmpty) Map.fromIterables(header, BrokerHttp.splitCsv(line).take(header.length)),
    ];
    _instrumentCache
      ..removeWhere((k, _) => k.startsWith('$exchange-'))
      ..[cacheKey] = rows;
    return rows;
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> request) async {
    final res = await request;
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw BrokerApiException('Kite returned HTTP ${res.statusCode}.');
    }
    if (res.statusCode != 200 || body['status'] != 'success') {
      throw BrokerApiException('Kite: ${body['message'] ?? 'HTTP ${res.statusCode}'}');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
