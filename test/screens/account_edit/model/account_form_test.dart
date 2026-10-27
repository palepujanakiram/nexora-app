import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/account_edit/model/account_form.dart';
import 'package:nexora_app/screens/account_edit/model/broker_setup_guide.dart';

void main() {
  test('new form defaults to a paper Zerodha account with one lot', () {
    final f = AccountForm.fromAccount(null);
    expect(f.broker, BrokerType.zerodha);
    expect(f.label, '');
    expect(f.apiKey, '');
    expect(f.apiSecret, '');
    expect(f.redirectUri, '');
    expect(f.lots, '1');
    expect(f.product, ProductType.carryForward);
    expect(f.paperMode, isTrue);
    expect(f.guide, same(BrokerSetupGuide.zerodha));
    expect(f.needsRedirectUri, isFalse);
  });

  test('fromAccount copies every editable field', () {
    const a = BrokerAccount(
      id: 'x',
      broker: BrokerType.upstox,
      label: 'Mine',
      apiKey: 'key',
      apiSecret: 'sec',
      redirectUri: 'https://127.0.0.1/',
      lots: 3,
      product: ProductType.intraday,
      paperMode: false,
    );
    final f = AccountForm.fromAccount(a);
    expect(f.broker, BrokerType.upstox);
    expect(f.label, 'Mine');
    expect(f.apiKey, 'key');
    expect(f.apiSecret, 'sec');
    expect(f.redirectUri, 'https://127.0.0.1/');
    expect(f.lots, '3');
    expect(f.product, ProductType.intraday);
    expect(f.paperMode, isFalse);
    expect(f.guide, same(BrokerSetupGuide.upstox));
    expect(f.needsRedirectUri, isTrue);
  });

  test('copyWith replaces only the given fields', () {
    const f = AccountForm(label: 'L', apiKey: 'k');
    final kept = f.copyWith();
    expect(kept.label, 'L');
    expect(kept.apiKey, 'k');
    expect(kept.paperMode, isTrue);

    final changed = f.copyWith(
      broker: BrokerType.upstox,
      label: 'M',
      apiKey: 'k2',
      apiSecret: 's2',
      redirectUri: 'r',
      lots: '5',
      product: ProductType.intraday,
      paperMode: false,
    );
    expect(changed.broker, BrokerType.upstox);
    expect(changed.label, 'M');
    expect(changed.apiKey, 'k2');
    expect(changed.apiSecret, 's2');
    expect(changed.redirectUri, 'r');
    expect(changed.lots, '5');
    expect(changed.product, ProductType.intraday);
    expect(changed.paperMode, isFalse);
  });

  test('required rejects null, empty and blank', () {
    expect(AccountForm.required(null), 'Required');
    expect(AccountForm.required(''), 'Required');
    expect(AccountForm.required('   '), 'Required');
    expect(AccountForm.required('x'), isNull);
  });

  test('validateLots needs a whole number of at least 1', () {
    for (final bad in [null, '', '0', '-2', '1.5', 'abc']) {
      expect(AccountForm.validateLots(bad), 'Enter a whole number ≥ 1', reason: '$bad');
    }
    expect(AccountForm.validateLots('1'), isNull);
    expect(AccountForm.validateLots('12'), isNull);
  });
}
