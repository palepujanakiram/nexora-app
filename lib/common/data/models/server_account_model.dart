import '../../domain/entities/broker_account.dart';

/// Maps the server's view of a broker account (`GET /broker-accounts`). The
/// server never sends the secret or the access token: [BrokerAccount.apiKey]
/// holds the masked key, the secret is empty, and a placeholder token stands
/// for "the broker session is valid".
///
/// The server keeps only the broker, name, mode and credentials. How many
/// lots, the product, whether the account is ticked by default and the Upstox
/// redirect URI are this device's own settings ([localJson]).
abstract final class ServerAccountModel {
  /// Stands in for the access token, which stays on the server.
  static const serverToken = 'on-server';

  /// Null for a broker this app doesn't support yet (e.g. Angel One).
  static BrokerAccount? fromJson(Map<String, dynamic> j, [Map<String, dynamic>? local]) {
    final broker = BrokerType.values.asNameMap()[j['broker']];
    if (broker == null) return null;
    final token = j['token'];
    final valid = token is Map && token['state'] == 'valid';
    final l = local ?? const {};
    return BrokerAccount(
      id: j['id'] as String,
      broker: broker,
      label: j['label'] as String,
      apiKey: j['apiKeyMasked'] as String? ?? '',
      apiSecret: '',
      redirectUri: l['redirectUri'] as String? ?? '',
      accessToken: valid ? serverToken : null,
      // The server decides whether the session is still good (it renews some
      // headlessly); paper accounts need no broker login at all.
      tokenIssuedAt: valid ? DateTime.now() : null,
      enabled: l['enabled'] as bool? ?? true,
      lots: l['lots'] as int? ?? 1,
      product: ProductType.values.asNameMap()[l['product']] ?? ProductType.carryForward,
      paperMode: j['mode'] != 'live',
    );
  }

  /// This device's settings for an account.
  static Map<String, Object?> localJson(BrokerAccount a) => {
    'enabled': a.enabled,
    'lots': a.lots,
    'product': a.product.name,
    if (a.redirectUri.isNotEmpty) 'redirectUri': a.redirectUri,
  };

  /// `POST /broker-accounts`. Credential names are the server's
  /// `credentialFields`; Upstox also needs the redirect URI.
  static Map<String, Object?> toCreateJson(BrokerAccount a) => {
    'broker': a.broker.name,
    'label': a.label,
    'mode': a.paperMode ? 'paper' : 'live',
    'credentials': {
      'apiKey': a.apiKey,
      'apiSecret': a.apiSecret,
      if (a.broker == BrokerType.upstox) 'redirectUri': a.redirectUri,
    },
  };

  /// What the server can't change on an existing account, or null. The key
  /// and secret count only when the user typed new ones: an untouched form
  /// still holds the masked key and no secret.
  static String? unchangeable(BrokerAccount before, BrokerAccount after) {
    if (after.broker != before.broker) return 'broker';
    if (after.label != before.label) return 'name';
    if (after.apiKey != before.apiKey || after.apiSecret.isNotEmpty) return 'API key or secret';
    if (after.broker == BrokerType.upstox && after.redirectUri != before.redirectUri && before.redirectUri.isNotEmpty) {
      return 'redirect URI';
    }
    return null;
  }
}
