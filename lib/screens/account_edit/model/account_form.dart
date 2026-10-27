import '../../../common/domain/entities/broker_account.dart';
import 'broker_setup_guide.dart';

/// Values entered on the account form.
class AccountForm {
  const AccountForm({
    this.broker = BrokerType.zerodha,
    this.label = '',
    this.apiKey = '',
    this.apiSecret = '',
    this.redirectUri = '',
    this.lots = '1',
    this.product = ProductType.carryForward,
    this.paperMode = true,
  });

  factory AccountForm.fromAccount(BrokerAccount? a) => a == null
      ? const AccountForm()
      : AccountForm(
          broker: a.broker,
          label: a.label,
          apiKey: a.apiKey,
          apiSecret: a.apiSecret,
          redirectUri: a.redirectUri,
          lots: '${a.lots}',
          product: a.product,
          paperMode: a.paperMode,
        );

  final BrokerType broker;
  final String label;
  final String apiKey;
  final String apiSecret;
  final String redirectUri;
  final String lots;
  final ProductType product;
  final bool paperMode;

  BrokerSetupGuide get guide => BrokerSetupGuide.of(broker);

  bool get needsRedirectUri => guide.needsRedirectUri;

  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  static String? validateLots(String? v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter a whole number ≥ 1' : null;

  AccountForm copyWith({
    BrokerType? broker,
    String? label,
    String? apiKey,
    String? apiSecret,
    String? redirectUri,
    String? lots,
    ProductType? product,
    bool? paperMode,
  }) =>
      AccountForm(
        broker: broker ?? this.broker,
        label: label ?? this.label,
        apiKey: apiKey ?? this.apiKey,
        apiSecret: apiSecret ?? this.apiSecret,
        redirectUri: redirectUri ?? this.redirectUri,
        lots: lots ?? this.lots,
        product: product ?? this.product,
        paperMode: paperMode ?? this.paperMode,
      );
}
