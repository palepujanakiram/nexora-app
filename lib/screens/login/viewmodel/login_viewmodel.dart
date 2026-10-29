import 'package:flutter/foundation.dart';

import '../model/login_state.dart';
import '../usecase/get_sign_in_notice_usecase.dart';
import '../usecase/sign_in_usecase.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._signIn, GetSignInNoticeUseCase notice) : _state = LoginState(notice: notice());

  final SignInUseCase _signIn;

  LoginState _state;
  LoginState get state => _state;

  bool _disposed = false;

  void setCreating(bool creating) => _emit(_state.copyWith(creating: creating, clearError: true));

  /// Signs in, or creates a login with [inviteCode] while [LoginState.creating].
  /// Returns true on success; the app then leaves the login screen.
  Future<bool> submit({required String url, required String email, required String password, String? inviteCode}) async {
    if (_state.busy) return false;
    _emit(_state.copyWith(busy: true, clearError: true));
    try {
      await _signIn(
        url: url,
        email: email,
        password: password,
        inviteCode: _state.creating ? inviteCode : null,
      );
      _emit(_state.copyWith(busy: false));
      return true;
    } catch (e) {
      _emit(_state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  void _emit(LoginState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
