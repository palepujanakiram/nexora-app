import '../../../common/domain/entities/sign_in_code.dart';
import '../../../common/domain/repositories/server_repository.dart';
import '../../../common/error/exceptions.dart';

/// Asks the server to text a sign-in code to an Indian mobile number.
class SendCodeUseCase {
  const SendCodeUseCase(this._server);

  /// The server's error code for a number that has no login yet.
  static const notRegistered = 'not_registered';

  /// Why [mobile] isn't an Indian mobile number, or null when it is.
  static String? problemWith(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) return 'Enter your 10-digit mobile number.';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Indian mobile numbers start with 6, 7, 8 or 9.';
    return null;
  }

  final ServerRepository _server;

  /// [mobile] is the 10-digit number, with or without spaces.
  Future<SignInCode> call({required String url, required String mobile}) async {
    final problem = problemWith(mobile);
    if (problem != null) throw ServerApiException(problem);
    final digits = mobile.replaceAll(RegExp(r'[\s-]'), '');
    return _server.requestCode(url: url, phone: '+91$digits');
  }
}
