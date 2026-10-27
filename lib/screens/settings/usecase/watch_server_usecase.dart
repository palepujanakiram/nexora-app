import '../../../common/domain/entities/server_session.dart';
import '../../../common/domain/repositories/server_repository.dart';

class WatchServerUseCase {
  const WatchServerUseCase(this._server);

  final ServerRepository _server;

  Stream<ServerSession?> call() => _server.watch();
}
