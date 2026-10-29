import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/error/exceptions.dart';
import '../model/login_state.dart';
import '../usecase/get_sign_in_notice_usecase.dart';
import '../usecase/send_code_usecase.dart';
import '../usecase/sign_in_usecase.dart';

/// Sign-in in two steps: the mobile number, then the code texted to it.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._sendCode, this._signIn, GetSignInNoticeUseCase notice)
      : _state = LoginState(notice: notice());

  final SendCodeUseCase _sendCode;
  final SignInUseCase _signIn;

  LoginState _state;
  LoginState get state => _state;

  /// Where the code was requested, and for which number, so resend and verify match.
  String _url = '';
  String _mobile = '';
  Timer? _countdown;
  bool _disposed = false;

  /// Shown when the server has no login for the number.
  static const userNotFound = 'User not found.';

  /// Texts a code to [mobile] and moves to the code step. Returns true once sent.
  Future<bool> sendCode({required String url, required String mobile}) async {
    _url = url;
    _mobile = mobile;
    return _send();
  }

  /// Sends another code to the same number once the wait is over.
  Future<bool> resend() async {
    if (_state.resendIn > 0) return false;
    return _send();
  }

  Future<bool> _send() => _run(() async {
        try {
          final sent = await _sendCode(url: _url, mobile: _mobile);
          _emit(_state.copyWith(sent: sent, resendIn: sent.resendIn.inSeconds));
          _startCountdown();
        } on ServerApiException catch (e) {
          if (e.code != SendCodeUseCase.notRegistered) rethrow;
          throw ServerApiException(userNotFound);
        }
      });

  /// Checks [code]. Returns true once signed in; the app then shows home.
  Future<bool> verify(String code) {
    final sent = _state.sent;
    if (sent == null) return Future.value(false);
    return _run(() => _signIn(url: _url, phone: sent.phone, code: code));
  }

  /// Back to the number step, e.g. to fix a typo.
  void changeNumber() {
    _countdown?.cancel();
    _emit(_state.copyWith(clearSent: true, resendIn: 0, clearError: true));
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

  void _emit(LoginState next) {
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
