import '../../../common/domain/entities/server_session.dart';
import '../../../common/domain/entities/sign_in_code.dart';

class LoginState {
  const LoginState({this.sent, this.needsInvite = false, this.resendIn = 0, this.busy = false, this.error, this.notice});

  /// The code the server texted, once the number is in. Null while asking for the number.
  final SignInCode? sent;

  /// The number has no login yet, so the server wants the owner's invite code.
  final bool needsInvite;

  /// Seconds until another code can be requested.
  final int resendIn;
  final bool busy;
  final String? error;

  /// Why the user is here without having signed out, e.g. an expired session.
  final String? notice;

  bool get enteringCode => sent != null;

  /// The number the code went to, e.g. `+91 98765 43210`.
  String? get sentTo => sent == null ? null : formatPhone(sent!.phone);

  LoginState copyWith({
    SignInCode? sent,
    bool clearSent = false,
    bool? needsInvite,
    int? resendIn,
    bool? busy,
    String? error,
    bool clearError = false,
  }) =>
      LoginState(
        sent: clearSent ? null : sent ?? this.sent,
        needsInvite: needsInvite ?? this.needsInvite,
        resendIn: resendIn ?? this.resendIn,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
        notice: notice,
      );
}
