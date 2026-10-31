import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/sign_up_details.dart';
import '../../../common/error/exceptions.dart';
import '../model/sign_up_consent.dart';
import '../model/sign_up_state.dart';
import '../usecase/send_sign_up_code_usecase.dart';
import '../usecase/sign_up_usecase.dart';

/// Sign-up in two steps: the form (name, number, email and the statements to
/// confirm), then the code texted to the number.
class SignUpViewModel extends ChangeNotifier {
  SignUpViewModel(this._sendCode, this._signUp);

  final SendSignUpCodeUseCase _sendCode;
  final SignUpUseCase _signUp;

  SignUpState _state = const SignUpState();
  SignUpState get state => _state;

  /// What the code was requested for, so resend and verify send the same form.
  String _url = '';
  String _mobile = '';
  SignUpDetails _details = const SignUpDetails(fullName: '', email: '');
  Timer? _countdown;
  bool _disposed = false;

  /// Ticks or unticks one statement.
  void confirm(SignUpConsent consent, bool ticked) {
    final next = {..._state.confirmed};
    ticked ? next.add(consent) : next.remove(consent);
    _emit(_state.copyWith(confirmed: next));
  }

  /// Texts a sign-up code and moves to the code step. Returns true once sent.
  Future<bool> sendCode({
    required String url,
    required String mobile,
    required String fullName,
    required String email,
  }) {
    _url = url;
    _mobile = mobile;
    final confirmed = _state.confirmed;
    _details = SignUpDetails(
      fullName: fullName,
      email: email,
      acceptsTerms: confirmed.contains(SignUpConsent.terms),
      acceptsRisk: confirmed.contains(SignUpConsent.risk),
      acceptsDataUse: confirmed.contains(SignUpConsent.dataUse),
    );
    return _send();
  }

  /// Sends another code for the same form once the wait is over.
  Future<bool> resend() async {
    if (_state.resendIn > 0) return false;
    return _send();
  }

  Future<bool> _send() => _run(() async {
        final sent = await _sendCode(url: _url, mobile: _mobile, details: _details);
        _emit(_state.copyWith(sent: sent, resendIn: sent.resendIn.inSeconds));
        _startCountdown();
      });

  /// Checks [code] and creates the account. Returns true once signed in.
  Future<bool> verify(String code) async {
    final sent = _state.sent;
    if (sent == null) return false;
    return _run(() async {
      try {
        await _signUp(url: _url, phone: sent.phone, details: _details, code: code);
      } on ServerApiException catch (e) {
        if (e.code == SignUpUseCase.alreadyRegistered) {
          _emit(_state.copyWith(alreadyRegistered: true));
        } else if (e.code == SignUpUseCase.emailTaken) {
          // Only the form can fix it: back to it, with the reason.
          _toForm();
        }
        rethrow;
      }
    });
  }

  /// Back to the form, e.g. to fix the number or email.
  void editDetails() {
    _toForm();
    _emit(_state.copyWith(clearError: true));
  }

  void _toForm() {
    _countdown?.cancel();
    _emit(_state.copyWith(clearSent: true, resendIn: 0));
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_state.busy) return false;
    _emit(_state.copyWith(busy: true, clearError: true));
    try {
      await action();
      _emit(_state.copyWith(busy: false));
      return true;
    } catch (e) {
      _emit(_state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  void _startCountdown() {
    _countdown?.cancel();
    if (_state.resendIn <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = _state.resendIn - 1;
      if (left <= 0) t.cancel();
      _emit(_state.copyWith(resendIn: left));
    });
  }

  void _emit(SignUpState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdown?.cancel();
    super.dispose();
  }
}
