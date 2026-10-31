import '../../../common/domain/entities/sign_in_code.dart';
import '../../../common/domain/entities/sign_up_details.dart';
import '../../../common/domain/repositories/server_repository.dart';
import '../../../common/domain/services/account_rules.dart';
import '../../../common/error/exceptions.dart';

/// Checks the sign-up form, then asks the server to text a sign-up code to
/// the Indian mobile number.
class SendSignUpCodeUseCase {
  const SendSignUpCodeUseCase(this._server);

  /// Shown when a statement isn't ticked; the server says the same.
  static const confirmEach = 'Please confirm each of the statements to create your account.';

  final ServerRepository _server;

  /// [mobile] is the 10-digit number, with or without spaces.
  Future<SignInCode> call({required String url, required String mobile, required SignUpDetails details}) async {
    final problem = AccountRules.fullNameProblem(details.fullName) ??
        AccountRules.mobileProblem(mobile) ??
        AccountRules.emailProblem(details.email) ??
        (details.confirmedAll ? null : confirmEach);
    if (problem != null) throw ServerApiException(problem);
    return _server.requestSignUpCode(url: url, phone: AccountRules.e164(mobile), details: details);
  }
}
