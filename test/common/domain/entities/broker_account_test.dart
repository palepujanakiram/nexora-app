import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';

const _ist = Duration(hours: 5, minutes: 30);

/// Most recent daily reset at [h]:[m] IST, as a UTC instant.
DateTime _lastReset(int h, int m) {
  final nowIst = DateTime.now().toUtc().add(_ist);
  var r = DateTime.utc(nowIst.year, nowIst.month, nowIst.day, h, m);
  if (r.isAfter(nowIst)) r = r.subtract(const Duration(days: 1));
  return r.subtract(_ist);
}

BrokerAccount _acc({
  BrokerType broker = BrokerType.zerodha,
  String apiKey = 'abcdefghij',
  String? token = 't',
  DateTime? issued,
}) =>
    BrokerAccount(
      id: 'id',
      broker: broker,
      label: 'L',
      apiKey: apiKey,
      apiSecret: 's',
      accessToken: token,
      tokenIssuedAt: issued,
    );

void main() {
  test('constructor defaults', () {
    const a = BrokerAccount(id: 'i', broker: BrokerType.upstox, label: 'L', apiKey: 'k', apiSecret: 's');
    expect(a.redirectUri, '');
    expect(a.accessToken, isNull);
    expect(a.tokenIssuedAt, isNull);
    expect(a.enabled, isTrue);
    expect(a.lots, 1);
    expect(a.product, ProductType.carryForward);
    expect(a.paperMode, isTrue);
  });

  test('enum labels', () {
    expect(BrokerType.zerodha.label, 'Zerodha (Kite Connect)');
    expect(BrokerType.upstox.label, 'Upstox');
    expect(ProductType.carryForward.label, 'Carry forward (NRML)');
    expect(ProductType.intraday.label, 'Intraday (MIS)');
  });

  group('hasValidToken', () {
    test('false without a token, with an empty token, or without issue time', () {
      expect(_acc(token: null, issued: DateTime.now()).hasValidToken, isFalse);
      expect(_acc(token: '', issued: DateTime.now()).hasValidToken, isFalse);
      expect(_acc(issued: null).hasValidToken, isFalse);
    });

    for (final broker in BrokerType.values) {
      test('${broker.name}: token issued just now is valid', () {
        expect(_acc(broker: broker, issued: DateTime.now()).hasValidToken, isTrue);
      });

      test('${broker.name}: token issued over a day ago is invalid', () {
        expect(
          _acc(broker: broker, issued: DateTime.now().subtract(const Duration(hours: 25))).hasValidToken,
          isFalse,
        );
      });
    }

    test('Kite resets at 06:00 IST', () {
      final reset = _lastReset(6, 0);
      expect(_acc(issued: reset.add(const Duration(minutes: 1))).hasValidToken, isTrue);
      expect(_acc(issued: reset.subtract(const Duration(minutes: 1))).hasValidToken, isFalse);
      expect(_acc(issued: reset).hasValidToken, isFalse, reason: 'must be strictly after the reset');
    });

    test('Upstox resets at 03:30 IST', () {
      final reset = _lastReset(3, 30);
      final up = BrokerType.upstox;
      expect(_acc(broker: up, issued: reset.add(const Duration(minutes: 1))).hasValidToken, isTrue);
      expect(_acc(broker: up, issued: reset.subtract(const Duration(minutes: 1))).hasValidToken, isFalse);
    });

    test('local (non-UTC) issue times are compared as instants', () {
      final reset = _lastReset(6, 0);
      expect(_acc(issued: reset.add(const Duration(minutes: 1)).toLocal()).hasValidToken, isTrue);
    });
  });

  group('maskedKey', () {
    test('short keys (<= 6 chars) are shown as is', () {
      expect(_acc(apiKey: 'abc').maskedKey, 'abc');
      expect(_acc(apiKey: 'abcdef').maskedKey, 'abcdef');
      expect(_acc(apiKey: '').maskedKey, '');
    });

    test('longer keys show the first 4 and last 2 characters', () {
      expect(_acc(apiKey: 'abcdefg').maskedKey, 'abcd••••fg');
      expect(_acc(apiKey: 'kite1234567890xy').maskedKey, 'kite••••xy');
    });
  });

  group('copyWith', () {
    final issued = DateTime.utc(2026, 1, 1);
    final base = BrokerAccount(
      id: 'id',
      broker: BrokerType.zerodha,
      label: 'L',
      apiKey: 'k',
      apiSecret: 's',
      redirectUri: 'r',
      accessToken: 't',
      tokenIssuedAt: issued,
      enabled: true,
      lots: 2,
      product: ProductType.carryForward,
      paperMode: true,
    );

    test('with no arguments keeps every field', () {
      final c = base.copyWith();
      expect(c.id, 'id');
      expect(c.broker, BrokerType.zerodha);
      expect(c.label, 'L');
      expect(c.apiKey, 'k');
      expect(c.apiSecret, 's');
      expect(c.redirectUri, 'r');
      expect(c.accessToken, 't');
      expect(c.tokenIssuedAt, issued);
      expect(c.enabled, isTrue);
      expect(c.lots, 2);
      expect(c.product, ProductType.carryForward);
      expect(c.paperMode, isTrue);
    });

    test('replaces given fields but never the id', () {
      final later = DateTime.utc(2026, 2, 2);
      final c = base.copyWith(
        broker: BrokerType.upstox,
        label: 'L2',
        apiKey: 'k2',
        apiSecret: 's2',
        redirectUri: 'r2',
        accessToken: 't2',
        tokenIssuedAt: later,
        enabled: false,
        lots: 5,
        product: ProductType.intraday,
        paperMode: false,
      );
      expect(c.id, 'id');
      expect(c.broker, BrokerType.upstox);
      expect(c.label, 'L2');
      expect(c.apiKey, 'k2');
      expect(c.apiSecret, 's2');
      expect(c.redirectUri, 'r2');
      expect(c.accessToken, 't2');
      expect(c.tokenIssuedAt, later);
      expect(c.enabled, isFalse);
      expect(c.lots, 5);
      expect(c.product, ProductType.intraday);
      expect(c.paperMode, isFalse);
    });

    test('clearToken removes token and issue time, even if new ones are given', () {
      final c = base.copyWith(clearToken: true);
      expect(c.accessToken, isNull);
      expect(c.tokenIssuedAt, isNull);
      expect(c.label, 'L');
      final c2 = base.copyWith(clearToken: true, accessToken: 'x', tokenIssuedAt: DateTime.now());
      expect(c2.accessToken, isNull);
      expect(c2.tokenIssuedAt, isNull);
    });
  });
}
