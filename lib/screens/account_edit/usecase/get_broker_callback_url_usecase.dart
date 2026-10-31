import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/server_repository.dart';

/// Where the broker sends the browser after its login: the signed-in server's
/// `/broker-callback/<broker>`. This is the redirect URL to register in the
/// broker's developer app. Null when signed out.
class GetBrokerCallbackUrlUseCase {
  const GetBrokerCallbackUrlUseCase(this._server);

  final ServerRepository _server;

  String? call(BrokerType broker) {
    final session = _server.current;
    return session == null ? null : '${session.url}/broker-callback/${broker.name}';
  }
}
