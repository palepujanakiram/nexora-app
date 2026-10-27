import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_plan.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../error/exceptions.dart';

/// Remote API for one broker account.
abstract interface class BrokerApi {
  String loginUrl();
  Future<String> exchangeToken(String redirectUrlOrCode);
  Future<ResolvedInstrument> resolve(TradeSignal signal);
  Future<List<PlacedOrder>> placeTrade(ResolvedInstrument instrument, TradePlan plan);
}

/// Shared HTTP helpers for broker APIs.
mixin BrokerHttp {
  String get corsProxy;

  /// Prefixes [target] with the proxy, e.g. `https://proxy.dev/https://api.kite.trade/...`.
  Uri url(String target) => Uri.parse(proxied(corsProxy, target));

  static String proxied(String proxy, String target) {
    final p = proxy.trim();
    if (p.isEmpty) return target;
    return p.endsWith('/') ? '$p$target' : '$p/$target';
  }

  /// Accepts either a bare code or a full redirect URL containing [param].
  static String extractParam(String input, String param) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    final fromUrl = uri?.queryParameters[param];
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
    if (trimmed.contains('://') || trimmed.contains('?')) {
      throw BrokerApiException('No "$param" found in the pasted URL.');
    }
    return trimmed;
  }
}
