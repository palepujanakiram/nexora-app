import '../entities/broker_account.dart';
import '../entities/execution_result.dart';
import '../entities/trade_plan.dart';
import '../entities/trade_signal.dart';

/// Talks to whichever broker an account belongs to.
abstract interface class BrokerRepository {
  /// Whether the user may paste an access token they made elsewhere. Not when
  /// a server holds the tokens.
  bool get acceptsAccessTokens;

  /// Whether the broker's redirect lands on a server that finishes the login
  /// by itself. The app then only opens the login page and waits
  /// ([checkLoggedIn]), instead of catching the redirect.
  bool get loginFinishesOnServer;

  /// Whether [account] is logged in to its broker now, as freshly as the
  /// repository can tell.
  Future<bool> checkLoggedIn(BrokerAccount account);

  /// URL the user opens to log in and authorise the app for today. A server
  /// issues a fresh one (with its own short-lived state) each time.
  Future<String> loginUrl(BrokerAccount account);

  /// Exchanges the request token / auth code (or the full redirect URL that
  /// contains it) for an access token.
  Future<String> exchangeToken(BrokerAccount account, String redirectUrlOrCode);

  Future<ResolvedInstrument> resolve(BrokerAccount account, TradeSignal signal);

  Future<List<PlacedOrder>> placeTrade(BrokerAccount account, ResolvedInstrument instrument, TradePlan plan);
}
