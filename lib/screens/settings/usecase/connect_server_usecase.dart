import '../../../common/domain/repositories/server_repository.dart';

/// Signs this device in to a nexora-backend server (or creates a login with
/// the owner's invite code), then moves the app's data to that server.
class ConnectServerUseCase {
  const ConnectServerUseCase(this._server, this._switchTo);

  final ServerRepository _server;
  final SwitchDataSource _switchTo;

  /// With an [inviteCode], creates a new login; otherwise signs in.
  Future<void> call({
    required String url,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    final code = inviteCode?.trim() ?? '';
    final session = code.isEmpty
        ? await _server.signIn(url: url, email: email, password: password)
        : await _server.register(url: url, email: email, password: password, inviteCode: code);
    await _switchTo(session);
  }
}
