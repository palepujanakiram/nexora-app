import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/account_edit/model/account_form.dart';
import 'package:nexora_app/screens/account_edit/usecase/delete_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/save_account_usecase.dart';

import '../../../fakes.dart';

void main() {
  const form = AccountForm(
    label: '  Mine  ',
    apiKey: ' k ',
    apiSecret: ' s ',
    redirectUri: ' https://127.0.0.1/ ',
    lots: ' 3 ',
    product: ProductType.intraday,
  );

  group('SaveAccountUseCase', () {
    test('creates a new enabled account with trimmed values and no token', () async {
      final repo = FakeAccountRepository();
      final a = await SaveAccountUseCase(repo)(form);
      expect(repo.current.single, same(a));
      expect(a.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(a.broker, BrokerType.zerodha);
      expect(a.label, 'Mine');
      expect(a.apiKey, 'k');
      expect(a.apiSecret, 's');
      expect(a.redirectUri, 'https://127.0.0.1/');
      expect(a.lots, 3);
      expect(a.product, ProductType.intraday);
      expect(a.paperMode, isTrue);
      expect(a.enabled, isTrue);
      expect(a.accessToken, isNull);
      expect(a.tokenIssuedAt, isNull);
    });

    test('new accounts get distinct ids', () async {
      final repo = FakeAccountRepository();
      final a = await SaveAccountUseCase(repo)(form);
      final b = await SaveAccountUseCase(repo)(form);
      expect(a.id, isNot(b.id));
      expect(repo.current, hasLength(2));
    });

    test('updating keeps id, enabled flag and token when key and broker are unchanged', () async {
      final existing = testAccount(enabled: false); // apiKey 'k', zerodha, logged in
      final repo = FakeAccountRepository([existing]);
      final a = await SaveAccountUseCase(repo)(form.copyWith(paperMode: false), existing: existing);
      expect(a.id, 'a');
      expect(a.enabled, isFalse);
      expect(a.accessToken, 't');
      expect(a.tokenIssuedAt, existing.tokenIssuedAt);
      expect(a.paperMode, isFalse);
      expect(repo.current.single.label, 'Mine');
    });

    test('changing the API key drops the token', () async {
      final existing = testAccount();
      final a = await SaveAccountUseCase(FakeAccountRepository([existing]))(form.copyWith(apiKey: 'other'),
          existing: existing);
      expect(a.accessToken, isNull);
      expect(a.tokenIssuedAt, isNull);
    });

    test('changing the broker drops the token', () async {
      final existing = testAccount();
      final a = await SaveAccountUseCase(FakeAccountRepository([existing]))(form.copyWith(broker: BrokerType.upstox),
          existing: existing);
      expect(a.broker, BrokerType.upstox);
      expect(a.accessToken, isNull);
      expect(a.tokenIssuedAt, isNull);
    });
  });

  test('DeleteAccountUseCase removes only that account', () async {
    final repo = FakeAccountRepository([testAccount(), testAccount(id: 'b')]);
    await DeleteAccountUseCase(repo)('a');
    expect(repo.current.map((a) => a.id), ['b']);
  });
}
