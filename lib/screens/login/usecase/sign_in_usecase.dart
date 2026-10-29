import '../../../common/domain/repositories/server_repository.dart';
import '../../../common/error/exceptions.dart';

/// Signs this device in with the code texted to [phone], then wires the app's
/// data to that server.
class SignInUseCase {
  const SignInUseCase(this._server, this._switchTo);

  final ServerRepository _server;
  final SwitchDataSource _switchTo;

  Future<void> call({required String url, required String phone, required String code}) async {
    final digits = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) throw ServerApiException('Enter the 6-digit code from the SMS.');
    await _switchTo(await _server.verifyCode(url: url, phone: phone, code: digits));
  }
}
