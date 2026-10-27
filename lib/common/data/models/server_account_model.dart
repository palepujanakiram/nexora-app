import '../../domain/entities/broker_account.dart';

/// Maps the server's view of an account. The server never sends the secret or
/// the access token: [BrokerAccount.apiKey] holds the masked key, the secret
/// is empty, and a placeholder token stands for "logged in today".
abstract final class ServerAccountModel {
  /// Stands in for the access token, which stays on the server.
  static const serverToken = 'on-server';

  static BrokerAccount fromJson(Map<String, dynamic> j) {
    final loggedIn = j['loggedIn'] as bool? ?? false;
    final issued = j['tokenIssuedAt'] as String?;
    return BrokerAccount(
      id: j['id'] as String,
      broker: BrokerType.values.byName(j['broker'] as String),
      label: j['label'] as String,
      apiKey: j['apiKeyMasked'] as String,
      apiSecret: '',
      redirectUri: j['redirectUri'] as String? ?? '',
      accessToken: loggedIn ? serverToken : null,
      tokenIssuedAt: loggedIn && issued != null ? DateTime.parse(issued) : null,
      enabled: j['enabled'] as bool? ?? true,
      lots: j['lots'] as int? ?? 1,
      product: ProductType.values.byName(j['product'] as String? ?? 'carryForward'),
      paperMode: j['paperMode'] as bool? ?? true,
    );
  }

  /// The broker login page from the server (it knows the full API key).
  static String loginUrl(Map<String, dynamic> j) {
    final login = j['login'];
    return login is Map ? login['url'] as String? ?? '' : '';
  }

  /// Every field, for creating the account on the server.
  static Map<String, Object?> toCreateJson(BrokerAccount a) => {
        'broker': a.broker.name,
        'label': a.label,
        'apiKey': a.apiKey,
        'apiSecret': a.apiSecret,
        'redirectUri': a.redirectUri,
        'enabled': a.enabled,
        'lots': a.lots,
        'product': a.product.name,
        'paperMode': a.paperMode,
      };

  /// Only what changed from [before]. The key and secret go only when the user
  /// typed new ones: an untouched form still holds the masked key and no secret.
  static Map<String, Object?> toPatchJson(BrokerAccount before, BrokerAccount after) => {
        if (after.broker != before.broker) 'broker': after.broker.name,
        if (after.label != before.label) 'label': after.label,
        if (after.apiKey != before.apiKey) 'apiKey': after.apiKey,
        if (after.apiSecret.isNotEmpty) 'apiSecret': after.apiSecret,
        if (after.redirectUri != before.redirectUri) 'redirectUri': after.redirectUri,
        if (after.enabled != before.enabled) 'enabled': after.enabled,
        if (after.lots != before.lots) 'lots': after.lots,
        if (after.product != before.product) 'product': after.product.name,
        if (after.paperMode != before.paperMode) 'paperMode': after.paperMode,
      };
}
