import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/broker_account_model.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';

void main() {
  final issued = DateTime.utc(2026, 10, 27, 4, 15);
  final full = BrokerAccount(
    id: 'id1',
    broker: BrokerType.upstox,
    label: 'Family',
    apiKey: 'key123456',
    apiSecret: 'sec',
    redirectUri: 'https://r.example/cb',
    accessToken: 'tok',
    tokenIssuedAt: issued,
    enabled: false,
    lots: 3,
    product: ProductType.intraday,
    paperMode: false,
  );

  test('toJson writes every field with enum names and ISO time', () {
    expect(BrokerAccountModel.toJson(full), {
      'id': 'id1',
      'broker': 'upstox',
      'label': 'Family',
      'apiKey': 'key123456',
      'apiSecret': 'sec',
      'redirectUri': 'https://r.example/cb',
      'accessToken': 'tok',
      'tokenIssuedAt': '2026-10-27T04:15:00.000Z',
      'enabled': false,
      'lots': 3,
      'product': 'intraday',
      'paperMode': false,
    });
  });

  test('toJson writes null token fields when logged out', () {
    const a = BrokerAccount(id: 'x', broker: BrokerType.zerodha, label: 'L', apiKey: 'k', apiSecret: 's');
    final j = BrokerAccountModel.toJson(a);
    expect(j['accessToken'], isNull);
    expect(j['tokenIssuedAt'], isNull);
    expect(j['broker'], 'zerodha');
    expect(j['product'], 'carryForward');
  });

  test('fromJson round-trips a fully populated account', () {
    final back = BrokerAccountModel.fromJson(BrokerAccountModel.toJson(full));
    expect(back.id, 'id1');
    expect(back.broker, BrokerType.upstox);
    expect(back.label, 'Family');
    expect(back.apiKey, 'key123456');
    expect(back.apiSecret, 'sec');
    expect(back.redirectUri, 'https://r.example/cb');
    expect(back.accessToken, 'tok');
    expect(back.tokenIssuedAt, issued);
    expect(back.enabled, isFalse);
    expect(back.lots, 3);
    expect(back.product, ProductType.intraday);
    expect(back.paperMode, isFalse);
  });

  test('fromJson applies defaults for missing optional fields', () {
    final a = BrokerAccountModel.fromJson({
      'id': 'x',
      'broker': 'zerodha',
      'label': 'L',
      'apiKey': 'k',
      'apiSecret': 's',
    });
    expect(a.redirectUri, '');
    expect(a.accessToken, isNull);
    expect(a.tokenIssuedAt, isNull);
    expect(a.enabled, isTrue);
    expect(a.lots, 1);
    expect(a.product, ProductType.carryForward);
    expect(a.paperMode, isTrue, reason: 'accounts default to paper mode');
  });

  test('fromJson rejects an unknown broker', () {
    expect(
      () => BrokerAccountModel.fromJson({'id': 'x', 'broker': 'nope', 'label': 'L', 'apiKey': 'k', 'apiSecret': 's'}),
      throwsArgumentError,
    );
  });
}
