import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/broker_account.dart';
import '../model/login_state.dart';
import '../usecase/get_login_url_usecase.dart';
import '../usecase/login_with_redirect_usecase.dart';
import '../usecase/set_access_token_usecase.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this.account, GetLoginUrlUseCase getLoginUrl, this._login, this._setToken)
      : _state = LoginState(
          loginUrl: getLoginUrl(account),
          codeName: account.broker == BrokerType.zerodha ? 'request_token' : 'code',
        );

  final BrokerAccount account;
  final LoginWithRedirectUseCase _login;
  final SetAccessTokenUseCase _setToken;

  LoginState _state;
  LoginState get state => _state;

  /// Returns true once a session is stored.
  Future<bool> loginWithRedirect(String input) => _run(input, () => _login(account, input));

  Future<bool> useAccessToken(String input) => _run(input, () => _setToken(account, input));

  Future<bool> _run(String input, Future<void> Function() action) async {
    if (input.trim().isEmpty || _state.busy) return false;
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

  void _emit(LoginState next) {
    _state = next;
    notifyListeners();
  }
}
