import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/services/account_rules.dart';

void main() {
  test('checks an Indian mobile number and writes it in E.164', () {
    for (final mobile in ['', '12345', '98765abc10', '98765432101']) {
      expect(AccountRules.mobileProblem(mobile), 'Enter your 10-digit mobile number.', reason: mobile);
    }
    expect(AccountRules.mobileProblem('1234567890'), 'Indian mobile numbers start with 6, 7, 8 or 9.');
    expect(AccountRules.mobileProblem('98765 43210'), isNull);
    expect(AccountRules.mobileProblem('98765-43210'), isNull);
    expect(AccountRules.e164('98765 43210'), '+919876543210');
  });

  test('accepts full names the server accepts', () {
    for (final name in ['Ravi Kumar', '  Ravi   Kumar ', "D'Souza", 'A. P. J. Abdul Kalam', 'Rāmānujan', 'रवि कुमार', 'Jo']) {
      expect(AccountRules.fullNameProblem(name), isNull, reason: name);
    }
    for (final name in ['', ' ', 'R', '1Ravi', 'Ravi_K', '-Ravi', 'Ravi 2', 'R${'a' * 100}']) {
      expect(AccountRules.fullNameProblem(name), 'Enter your full name.', reason: name);
    }
  });

  test('checks the email', () {
    expect(AccountRules.emailProblem(' ravi@example.com '), isNull);
    for (final email in ['', 'ravi', 'ravi@example', 'ra vi@example.com', '@example.com', '${'a' * 190}@example.com']) {
      expect(AccountRules.emailProblem(email), 'Enter a valid email address.', reason: email);
    }
  });
}
