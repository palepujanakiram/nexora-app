import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/sign_in_code.dart';
import 'package:nexora_app/screens/signup/model/sign_up_consent.dart';
import 'package:nexora_app/screens/signup/model/sign_up_state.dart';

void main() {
  const code = SignInCode(phone: '+919876543210', expiresIn: Duration(minutes: 5), resendIn: Duration(seconds: 30));

  test('starts on the form with nothing ticked', () {
    const state = SignUpState();
    expect([state.enteringCode, state.sentTo, state.busy, state.error, state.alreadyRegistered, state.confirmed],
        [false, null, false, null, false, isEmpty]);
  });

  test('copies with changes, and clears the code and error on request', () {
    final sent = const SignUpState().copyWith(confirmed: {SignUpConsent.terms}, sent: code, resendIn: 30, busy: true);
    expect([sent.enteringCode, sent.sentTo, sent.resendIn, sent.busy], [true, '+91 98765 43210', 30, true]);
    expect(sent.confirmed, {SignUpConsent.terms});

    final failed = sent.copyWith(error: 'Taken', alreadyRegistered: true);
    expect([failed.error, failed.alreadyRegistered, failed.enteringCode], ['Taken', true, true]);
    expect(failed.copyWith(busy: false).alreadyRegistered, isTrue, reason: 'kept until the error clears');

    final cleared = failed.copyWith(clearError: true, clearSent: true);
    expect([cleared.error, cleared.alreadyRegistered, cleared.enteringCode], [null, false, false]);
    expect(cleared.confirmed, {SignUpConsent.terms}, reason: 'ticks survive going back to the form');
  });

  test('has one statement per server consent', () {
    expect(SignUpConsent.values.map((c) => c.name), ['terms', 'risk', 'dataUse']);
    expect(SignUpConsent.values.every((c) => c.statement.endsWith('.')), isTrue);
    expect(SignUpConsent.terms.statement, 'I have read and accept the Terms of Use and the Privacy Notice.');
    expect(SignUpConsent.risk.statement, contains('SEBI studies show most individual traders lose money.'));
    expect(SignUpConsent.risk.statement, endsWith('the decisions and any losses are mine.'));
    expect(SignUpConsent.dataUse.statement, contains('keep my broker connections'));
  });

  test('names the support team when the build sets no support email', () {
    expect(supportEmail, isEmpty);
    expect(supportContact, 'our support team');
    expect(SignUpConsent.dataUse.statement,
        endsWith('I can withdraw this consent at any time by writing to our support team.'));
  });
}
