import '../../../common/domain/entities/sign_in_code.dart';
import '../../../common/domain/repositories/server_repository.dart';
import '../../../common/domain/services/account_rules.dart';
import '../../../common/error/exceptions.dart';

/// Asks the server to text a sign-in code to an Indian mobile number.
class SendCodeUseCase {
  const SendCodeUseCase(this._server);

  /// The server's error code for a number that has no login yet.
  static const notRegistered = 'not_registered';

  /// Why [mobile] isn't an Indian mobile number, or null when it is.
  static String? problemWith(String mobile) => AccountRules.mobileProblem(mobile);

  final ServerRepository _server;

  /// [mobile] is the 10-digit number, with or without spaces.
  Future<SignInCode> call({required String url, required String mobile}) async {
    final problem = problemWith(mobile);
    if (problem != null) throw ServerApiException(problem);
    return _server.requestCode(url: url, phone: AccountRules.e164(mobile));
  }
}
