import '../../../common/domain/repositories/server_repository.dart';
import '../../../common/error/exceptions.dart';

/// Changes the server password. Every other device is signed out; this one
/// moves to the new session the server returns.
class ChangePasswordUseCase {
  const ChangePasswordUseCase(this._server, this._switchTo);

  /// The server's minimum, checked here so the user hears it before sending.
  static const minLength = 10;

  final ServerRepository _server;
  final SwitchDataSource _switchTo;

  Future<void> call({required String currentPassword, required String newPassword}) async {
    if (newPassword.length < minLength) {
      throw ServerApiException('Use at least $minLength characters for the new password.');
    }
    if (newPassword == currentPassword) throw ServerApiException('Choose a new password that differs from the current one.');
    await _switchTo(await _server.changePassword(currentPassword: currentPassword, newPassword: newPassword));
  }
}
