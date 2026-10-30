import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/server_account_model.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';

import '../repositories/server/fake_server.dart';

void main() {
  test('fromJson maps the server view with this device\'s settings; the secret and token never arrive', () {
    final a = ServerAccountModel.fromJson(
      accountJson(mode: 'live', state: 'valid'),
      {'enabled': false, 'lots': 3, 'product': 'intraday', 'redirectUri': 'https://cb.test/'},
    )!;
    expect(a.id, 'acc1');
    expect(a.broker, BrokerType.upstox);
    expect(a.label, 'Family');
    expect(a.apiKey, 'up••••34');
    expect(a.apiSecret, '');
    expect(a.accessToken, ServerAccountModel.serverToken);
    expect(a.hasValidToken, isTrue);
    expect([a.enabled, a.lots, a.product, a.paperMode, a.redirectUri], [false, 3, ProductType.intraday, false, 'https://cb.test/']);
  });

  test('fromJson leaves the token empty unless the session is valid, and fills defaults', () {
    for (final state in ['none', 'expired', 'needs_user_action']) {
      final a = ServerAccountModel.fromJson(accountJson(mode: 'live', state: state))!;
      expect([a.accessToken, a.tokenIssuedAt], [null, null], reason: state);
    }
    final a = ServerAccountModel.fromJson({'id': 'z', 'broker': 'zerodha', 'label': 'Z', 'mode': 'paper'})!;
    expect([a.apiKey, a.enabled, a.lots, a.product, a.paperMode, a.redirectUri],
        ['', true, 1, ProductType.carryForward, true, '']);
  });

  test('fromJson skips brokers this app doesn\'t support', () {
    expect(ServerAccountModel.fromJson(accountJson(broker: 'angelone')), isNull);
  });

  test('toCreateJson sends the mode and credentials; only Upstox sends a redirect URI', () {
    const zerodha = BrokerAccount(
        id: 'local', broker: BrokerType.zerodha, label: 'Main', apiKey: 'key', apiSecret: 'secret', paperMode: false);
    expect(ServerAccountModel.toCreateJson(zerodha), {
      'broker': 'zerodha',
      'label': 'Main',
      'mode': 'live',
      'credentials': {'apiKey': 'key', 'apiSecret': 'secret'},
    });
    final upstox = zerodha.copyWith(broker: BrokerType.upstox, redirectUri: 'https://cb.test/', paperMode: true);
    expect(ServerAccountModel.toCreateJson(upstox), {
      'broker': 'upstox',
      'label': 'Main',
      'mode': 'paper',
      'credentials': {'apiKey': 'key', 'apiSecret': 'secret', 'redirectUri': 'https://cb.test/'},
    });
  });

  test('localJson keeps what the server doesn\'t store', () {
    const a = BrokerAccount(id: 'x', broker: BrokerType.groww, label: 'G', apiKey: 'k', apiSecret: '', lots: 2);
    expect(ServerAccountModel.localJson(a), {'enabled': true, 'lots': 2, 'product': 'carryForward'});
  });

  test('unchangeable names what only a new account can change', () {
    final before = ServerAccountModel.fromJson(accountJson())!;
    expect(ServerAccountModel.unchangeable(before, before.copyWith(lots: 4, enabled: false, paperMode: false)), isNull);
    expect(ServerAccountModel.unchangeable(before, before.copyWith(redirectUri: 'https://cb.test/')), isNull,
        reason: 'not known here yet, so it can be filled in');
    expect(ServerAccountModel.unchangeable(before, before.copyWith(broker: BrokerType.groww)), 'broker');
    expect(ServerAccountModel.unchangeable(before, before.copyWith(label: 'New')), 'name');
    expect(ServerAccountModel.unchangeable(before, before.copyWith(apiKey: 'fresh')), 'API key or secret');
    expect(ServerAccountModel.unchangeable(before, before.copyWith(apiSecret: 'fresh')), 'API key or secret');
    final known = before.copyWith(redirectUri: 'https://a.test/');
    expect(ServerAccountModel.unchangeable(known, known.copyWith(redirectUri: 'https://b.test/')), 'redirect URI');
  });
}
