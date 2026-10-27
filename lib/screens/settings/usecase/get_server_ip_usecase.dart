import '../../../common/domain/repositories/server_repository.dart';

/// The IP brokers see the server's orders coming from.
class GetServerIpUseCase {
  const GetServerIpUseCase(this._server);

  final ServerRepository _server;

  Future<String> call() => _server.serverIp();
}
