import '../../../common/domain/entities/sign_up_details.dart';
import '../../../common/domain/repositories/server_repository.dart';
import '../../../common/error/exceptions.dart';

/// Creates the account with the sign-up code texted to [phone], signs this
/// device in, then wires the app's data to that server.
class SignUpUseCase {
  const SignUpUseCase(this._server, this._switchTo);

  /// The server's error code for a number that already has an account.
  static const alreadyRegistered = 'already_registered';

  /// The server's error code for an email that belongs to another account.
  static const emailTaken = 'conflict';

  final ServerRepository _server;
  final SwitchDataSource _switchTo;

  Future<void> call({
    required String url,
    required String phone,
    required SignUpDetails details,
    required String code,
  }) async {
    final digits = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) throw ServerApiException('Enter the 6-digit code from the SMS.');
    await _switchTo(await _server.verifySignUp(url: url, phone: phone, details: details, code: digits));
  }
}
