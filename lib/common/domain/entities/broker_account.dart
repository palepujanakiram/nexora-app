enum BrokerType {
  zerodha('Zerodha (Kite Connect)'),
  upstox('Upstox'),
  groww('Groww');

  const BrokerType(this.label);
  final String label;
}

/// Carry-forward (Kite/Groww NRML, Upstox D) or intraday (Kite/Groww MIS, Upstox I).
enum ProductType {
  carryForward('Carry forward (NRML)'),
  intraday('Intraday (MIS)');

  const ProductType(this.label);
  final String label;
}

/// One set of API credentials for a broker. A user can configure any number
/// of these per broker (e.g. family accounts, or several Kite Connect apps).
class BrokerAccount {
  const BrokerAccount({
    required this.id,
    required this.broker,
    required this.label,
    required this.apiKey,
    required this.apiSecret,
    this.redirectUri = '',
    this.accessToken,
    this.tokenIssuedAt,
    this.enabled = true,
    this.lots = 1,
    this.product = ProductType.carryForward,
    this.paperMode = true,
  });

  final String id;
  final BrokerType broker;
  final String label;
  final String apiKey;
  final String apiSecret;

  /// Upstox needs the exact redirect URI registered for the app.
  final String redirectUri;
  final String? accessToken;
  final DateTime? tokenIssuedAt;

  /// Whether the account is pre-selected when executing a signal.
  final bool enabled;

  /// Number of lots to trade per signal on this account.
  final int lots;
  final ProductType product;

  /// Paper accounts never send orders to the broker.
  final bool paperMode;

  /// Broker sessions expire daily: Kite and Groww at 06:00 IST, Upstox at 03:30 IST.
  bool get hasValidToken {
    final token = accessToken;
    final issued = tokenIssuedAt;
    if (token == null || token.isEmpty || issued == null) return false;
    final (h, m) = broker == BrokerType.upstox ? (3, 30) : (6, 0);
    return issued.toUtc().isAfter(_lastIstReset(h, m));
  }

  static DateTime _lastIstReset(int hour, int minute) {
    const ist = Duration(hours: 5, minutes: 30);
    final nowIst = DateTime.now().toUtc().add(ist);
    var reset = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, hour, minute);
    if (nowIst.isBefore(reset)) reset = reset.subtract(const Duration(days: 1));
    return reset.subtract(ist);
  }

  String get maskedKey =>
      apiKey.length <= 6 ? apiKey : '${apiKey.substring(0, 4)}••••${apiKey.substring(apiKey.length - 2)}';

  BrokerAccount copyWith({
    BrokerType? broker,
    String? label,
    String? apiKey,
    String? apiSecret,
    String? redirectUri,
    String? accessToken,
    DateTime? tokenIssuedAt,
    bool? enabled,
    int? lots,
    ProductType? product,
    bool? paperMode,
    bool clearToken = false,
  }) {
    return BrokerAccount(
      id: id,
      broker: broker ?? this.broker,
      label: label ?? this.label,
      apiKey: apiKey ?? this.apiKey,
      apiSecret: apiSecret ?? this.apiSecret,
      redirectUri: redirectUri ?? this.redirectUri,
      accessToken: clearToken ? null : accessToken ?? this.accessToken,
      tokenIssuedAt: clearToken ? null : tokenIssuedAt ?? this.tokenIssuedAt,
      enabled: enabled ?? this.enabled,
      lots: lots ?? this.lots,
      product: product ?? this.product,
      paperMode: paperMode ?? this.paperMode,
    );
  }
}
