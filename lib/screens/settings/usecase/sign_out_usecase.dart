import '../../../common/domain/repositories/server_repository.dart';

/// Signs this device out of the server; the app goes back to the login screen.
class SignOutUseCase {
  const SignOutUseCase(this._server, this._switchTo);

  final ServerRepository _server;
  final SwitchDataSource _switchTo;

  Future<void> call() async {
    await _server.signOut();
    await _switchTo(null);
  }
}
