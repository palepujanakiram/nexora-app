import '../../../common/domain/repositories/server_repository.dart';

/// Signs this device out of the server; the app goes back to the accounts
/// stored on this device.
class DisconnectServerUseCase {
  const DisconnectServerUseCase(this._server, this._switchTo);

  final ServerRepository _server;
  final SwitchDataSource _switchTo;

  Future<void> call() async {
    await _server.signOut();
    await _switchTo(null);
  }
}
