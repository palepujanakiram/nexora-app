import '../../domain/entities/broker_account.dart';

/// JSON mapping for [BrokerAccount].
abstract final class BrokerAccountModel {
  static Map<String, dynamic> toJson(BrokerAccount a) => {
        'id': a.id,
        'broker': a.broker.name,
        'label': a.label,
        'apiKey': a.apiKey,
        'apiSecret': a.apiSecret,
        'redirectUri': a.redirectUri,
        'accessToken': a.accessToken,
        'tokenIssuedAt': a.tokenIssuedAt?.toIso8601String(),
        'enabled': a.enabled,
        'lots': a.lots,
        'product': a.product.name,
        'paperMode': a.paperMode,
      };

  static BrokerAccount fromJson(Map<String, dynamic> j) => BrokerAccount(
        id: j['id'] as String,
        broker: BrokerType.values.byName(j['broker'] as String),
        label: j['label'] as String,
        apiKey: j['apiKey'] as String,
        apiSecret: j['apiSecret'] as String,
        redirectUri: j['redirectUri'] as String? ?? '',
        accessToken: j['accessToken'] as String?,
        tokenIssuedAt: j['tokenIssuedAt'] == null ? null : DateTime.parse(j['tokenIssuedAt'] as String),
        enabled: j['enabled'] as bool? ?? true,
        lots: j['lots'] as int? ?? 1,
        product: ProductType.values.byName(j['product'] as String? ?? 'carryForward'),
        paperMode: j['paperMode'] as bool? ?? true,
      );
}
