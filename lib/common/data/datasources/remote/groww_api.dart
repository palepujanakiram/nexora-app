import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../domain/entities/broker_account.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_plan.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../error/exceptions.dart';
import 'broker_api.dart';

/// Groww Trade API. Docs: https://groww.in/trade-api/docs/curl
///
/// Groww has no redirect login: the user approves the API key for the day on
/// Groww's API Keys page, then the app creates a token from the key and a
/// checksum of the secret (or from a TOTP code).
///
/// Stop loss / target aren't placed: Groww's OCO needs an existing position,
/// so it can only be created after the entry fills.
class GrowwApi with BrokerHttp implements BrokerApi {
  GrowwApi(this.account, this._http, this.corsProxy, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  static const _base = 'https://api.groww.in';
  static const instrumentsUrl = 'https://growwapi-assets.groww.in/instruments/instrument.csv';
  static const apiKeysPage = 'https://groww.in/trade-api/api-keys';

  /// The instrument list covers every segment and changes once a day, so it's
  /// cached per day across all Groww accounts.
  static (String, List<Map<String, String>>)? _instrumentCache;

  final BrokerAccount account;
  final http.Client _http;
  final DateTime Function() _clock;
  final Random _random;
  @override
  final String corsProxy;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${account.accessToken}',
        'Accept': 'application/json',
        'X-API-VERSION': '1.0',
      };

  @override
  String loginUrl() => apiKeysPage;

  /// [input] is empty for the daily-approval flow, or a 6-digit TOTP code.
  @override
  Future<String> exchangeToken(String input) async {
    final code = input.trim();
    final Map<String, String> body;
    if (RegExp(r'^\d{6}$').hasMatch(code)) {
      body = {'key_type': 'totp', 'totp': code};
    } else if (code.isEmpty) {
      final timestamp = '${_clock().millisecondsSinceEpoch ~/ 1000}';
      final checksum = sha256.convert(utf8.encode('${account.apiSecret}$timestamp')).toString();
      body = {'key_type': 'approval', 'checksum': checksum, 'timestamp': timestamp};
    } else {
      throw BrokerApiException('Groww: leave the box empty, or enter the 6-digit TOTP code.');
    }
    final res = await _http.post(
      url('$_base/v1/token/api/access'),
      headers: {'Authorization': 'Bearer ${account.apiKey}', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decode(res);
    final payload = data['payload'];
    final token = data['token'] ?? (payload is Map ? payload['token'] : null);
    if (res.statusCode >= 300 || token is! String || token.isEmpty) {
      throw BrokerApiException('Groww: ${_error(data, res)}');
    }
    return token;
  }

  @override
  Future<ResolvedInstrument> resolve(TradeSignal signal) async {
    final exchange = _exchange(signal);
    for (final r in await _instruments()) {
      if (r['exchange'] == exchange &&
          r['segment'] == 'FNO' &&
          r['underlying_symbol'] == signal.underlying &&
          r['instrument_type'] == signal.optionCode &&
          r['expiry_date'] == signal.expiryIso &&
          double.tryParse(r['strike_price'] ?? '') == signal.strike) {
        return ResolvedInstrument(
          symbol: r['trading_symbol']!,
          exchange: exchange,
          lotSize: int.parse(r['lot_size']!),
          tickSize: double.tryParse(r['tick_size'] ?? '') ?? 0.05,
        );
      }
    }
    throw BrokerApiException('No Groww contract found for ${signal.contractLabel} on $exchange.');
  }

  @override
  Future<List<PlacedOrder>> placeTrade(ResolvedInstrument inst, TradePlan plan) async {
    final res = await _http.post(
      url('$_base/v1/order/create'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'trading_symbol': inst.symbol,
        'quantity': plan.quantity,
        'price': double.parse(plan.entryPrice.toStringAsFixed(2)),
        'validity': 'DAY',
        'exchange': inst.exchange,
        'segment': 'FNO',
        'product': plan.product == ProductType.intraday ? 'MIS' : 'NRML',
        'order_type': 'LIMIT',
        'transaction_type': plan.signal.side,
        'order_reference_id': _referenceId(),
      }),
    );
    final data = _decode(res);
    final payload = data['payload'];
    if (res.statusCode >= 300 || data['status'] != 'SUCCESS' || payload is! Map) {
      throw BrokerApiException('Groww: ${_error(data, res)}');
    }
    return [
      PlacedOrder('ENTRY', '${payload['groww_order_id']}'),
      if (plan.hasExits)
        PlacedOrder('SL ${plan.stopLoss} / TGT ${plan.target}', 'not placed: add an OCO in the Groww app after the entry fills'),
    ];
  }

  /// SENSEX/BANKEX options trade on BSE, the rest on NSE.
  static String _exchange(TradeSignal signal) => signal.exchange == 'BFO' ? 'BSE' : 'NSE';

  /// 8–20 characters, letters/digits and at most two hyphens.
  String _referenceId() => 'NX${_clock().millisecondsSinceEpoch}${_random.nextInt(1000).toString().padLeft(3, '0')}';

  Future<List<Map<String, String>>> _instruments() async {
    final now = _clock();
    final day = '${now.year}-${now.month}-${now.day}';
    final cached = _instrumentCache;
    if (cached != null && cached.$1 == day) return cached.$2;

    final res = await _http.get(url(instrumentsUrl));
    if (res.statusCode != 200) {
      throw BrokerApiException('Groww instruments download failed (${res.statusCode}).');
    }
    final lines = const LineSplitter().convert(res.body);
    if (lines.isEmpty) throw BrokerApiException('Groww instruments list was empty.');
    final header = BrokerHttp.splitCsv(lines.first);
    final rows = [
      for (final line in lines.skip(1))
        if (line.isNotEmpty) _row(header, BrokerHttp.splitCsv(line)),
    ];
    _instrumentCache = (day, rows);
    return rows;
  }

  static Map<String, String> _row(List<String> header, List<String> cells) =>
      {for (var i = 0; i < header.length && i < cells.length; i++) header[i]: cells[i]};

  @visibleForTesting
  static void clearCache() => _instrumentCache = null;

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
    } catch (_) {
      // Fall through to the HTTP status.
    }
    if (res.statusCode >= 300) throw BrokerApiException('Groww returned HTTP ${res.statusCode}.');
    return const {};
  }

  static String _error(Map<String, dynamic> body, http.Response res) {
    final error = body['error'];
    if (error is Map && error['message'] != null) return '${error['message']}';
    return '${body['message'] ?? 'HTTP ${res.statusCode}'}';
  }
}
