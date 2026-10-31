import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/sign_up_details.dart';

void main() {
  test('is confirmed only when every statement is ticked', () {
    const none = SignUpDetails(fullName: 'Ravi Kumar', email: 'ravi@example.com');
    expect([none.acceptsTerms, none.acceptsRisk, none.acceptsDataUse, none.confirmedAll], [false, false, false, false]);
    expect(
      const SignUpDetails(fullName: 'R', email: 'e', acceptsTerms: true, acceptsRisk: true).confirmedAll,
      isFalse,
    );
    expect(
      const SignUpDetails(fullName: 'R', email: 'e', acceptsTerms: true, acceptsRisk: true, acceptsDataUse: true)
          .confirmedAll,
      isTrue,
    );
  });
}
