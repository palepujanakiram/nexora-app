import '../../../common/domain/entities/server_session.dart';
import '../../../common/domain/entities/sign_in_code.dart';
import 'sign_up_consent.dart';

class SignUpState {
  const SignUpState({
    this.confirmed = const {},
    this.sent,
    this.resendIn = 0,
    this.busy = false,
    this.error,
    this.alreadyRegistered = false,
  });

  /// The statements ticked so far.
  final Set<SignUpConsent> confirmed;

  /// The sign-up code the server texted, once the form is in. Null while filling in the form.
  final SignInCode? sent;

  /// Seconds until another code can be requested.
  final int resendIn;
  final bool busy;
  final String? error;

  /// The number already has an account: offer to sign in instead.
  final bool alreadyRegistered;

  bool get enteringCode => sent != null;

  /// The number the code went to, e.g. `+91 98765 43210`.
  String? get sentTo => sent == null ? null : formatPhone(sent!.phone);

  SignUpState copyWith({
    Set<SignUpConsent>? confirmed,
    SignInCode? sent,
    bool clearSent = false,
    int? resendIn,
    bool? busy,
    String? error,
    bool clearError = false,
    bool? alreadyRegistered,
  }) =>
      SignUpState(
        confirmed: confirmed ?? this.confirmed,
        sent: clearSent ? null : sent ?? this.sent,
        resendIn: resendIn ?? this.resendIn,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
        alreadyRegistered: alreadyRegistered ?? (clearError ? false : this.alreadyRegistered),
      );
}
