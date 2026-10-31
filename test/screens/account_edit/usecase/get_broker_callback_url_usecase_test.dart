import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/account_edit/usecase/get_broker_callback_url_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('is the signed-in server\'s callback for the broker, or null when signed out', () {
    final server = FakeServerRepository(const ServerSession(url: 'https://srv.test', token: 't', phone: '+919876543210'));
    final callback = GetBrokerCallbackUrlUseCase(server);
    expect(callback(BrokerType.upstox), 'https://srv.test/broker-callback/upstox');
    expect(callback(BrokerType.zerodha), 'https://srv.test/broker-callback/zerodha');
    server.expire();
    expect(callback(BrokerType.upstox), isNull);
  });
}
