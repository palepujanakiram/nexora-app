import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/error/exceptions.dart';

void main() {
  test('SignalParseException exposes its message', () {
    final e = SignalParseException('No strike found');
    expect(e, isA<Exception>());
    expect(e.message, 'No strike found');
    expect(e.toString(), 'No strike found');
  });

  test('BrokerApiException exposes its message', () {
    final e = BrokerApiException('HTTP 403: TokenException');
    expect(e, isA<Exception>());
    expect(e.message, 'HTTP 403: TokenException');
    expect('$e', 'HTTP 403: TokenException');
  });
}
