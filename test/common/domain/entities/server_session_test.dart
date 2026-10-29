import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';

void main() {
  test('shows Indian numbers in groups and leaves others as they are', () {
    expect(formatPhone('+919876543210'), '+91 98765 43210');
    expect(formatPhone('+14155550100'), '+14155550100');
    expect(const ServerSession(url: 'u', token: 't', phone: '+919876543210').phoneLabel, '+91 98765 43210');
  });
}
