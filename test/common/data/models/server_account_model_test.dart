import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/server_account_model.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';

import '../repositories/server/fake_server.dart';

void main() {
  test('fromJson maps the server view; the secret and token never arrive', () {
    final a = ServerAccountModel.fromJson(accountJson(loggedIn: true, lots: 3));
    expect(a.id, 'acc1');
    expect(a.broker, BrokerType.upstox);
    expect(a.apiKey, 'upke••••34');
    expect(a.apiSecret, '');
    expect(a.accessToken, ServerAccountModel.serverToken);
    expect(a.tokenIssuedAt, DateTime.utc(2026, 10, 27, 4));
    expect(a.lots, 3);
    expect(a.product, ProductType.intraday);
    expect(a.paperMode, isTrue);
  });

  test('fromJson leaves the token empty when logged out, and fills defaults', () {
    final a = ServerAccountModel.fromJson({
      'id': 'z',
      'broker': 'zerodha',
      'label': 'Z',
      'apiKeyMasked': 'k',
    });
    expect(a.accessToken, isNull);
    expect(a.tokenIssuedAt, isNull);
    expect([a.enabled, a.lots, a.product, a.paperMode, a.redirectUri], [true, 1, ProductType.carryForward, true, '']);
    expect(ServerAccountModel.loginUrl({'login': null}), '');
    expect(ServerAccountModel.loginUrl(accountJson()), 'https://login.example/acc1');
  });

  test('toCreateJson sends every field', () {
    const a = BrokerAccount(
      id: 'local',
      broker: BrokerType.zerodha,
      label: 'Main',
      apiKey: 'key',
      apiSecret: 'secret',
      lots: 2,
      paperMode: false,
    );
    expect(ServerAccountModel.toCreateJson(a), {
      'broker': 'zerodha',
      'label': 'Main',
      'apiKey': 'key',
      'apiSecret': 'secret',
      'redirectUri': '',
      'enabled': true,
      'lots': 2,
      'product': 'carryForward',
      'paperMode': false,
    });
  });

  test('toPatchJson sends only changes, and never the masked key or an empty secret', () {
    final before = ServerAccountModel.fromJson(accountJson());
    expect(ServerAccountModel.toPatchJson(before, before), isEmpty);
    final after = before.copyWith(
      broker: BrokerType.groww,
      label: 'New',
      apiKey: 'fresh-key',
      apiSecret: 'fresh-secret',
      redirectUri: 'https://localhost/',
      enabled: false,
      lots: 4,
      product: ProductType.carryForward,
      paperMode: false,
    );
    expect(ServerAccountModel.toPatchJson(before, after), {
      'broker': 'groww',
      'label': 'New',
      'apiKey': 'fresh-key',
      'apiSecret': 'fresh-secret',
      'redirectUri': 'https://localhost/',
      'enabled': false,
      'lots': 4,
      'product': 'carryForward',
      'paperMode': false,
    });
  });
}
