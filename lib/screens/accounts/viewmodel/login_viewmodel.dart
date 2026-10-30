import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/broker_account.dart';
import '../model/login_state.dart';
import '../usecase/get_login_url_usecase.dart';
import '../usecase/login_with_redirect_usecase.dart';
import '../usecase/set_access_token_usecase.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this.account, GetLoginUrlUseCase getLoginUrl, this._login, this._setToken)
      : _state = LoginState(
          loginUrl: '',
          codeName: switch (account.broker) {
            BrokerType.zerodha => 'request_token',
            BrokerType.upstox => 'code',
            BrokerType.groww => 'TOTP code',
          },
          redirectLogin: account.broker != BrokerType.groww,
          acceptsAccessToken: getLoginUrl.acceptsAccessTokens,
        ) {
    _loadUrl(getLoginUrl);
  }

  final BrokerAccount account;
  final LoginWithRedirectUseCase _login;
  final SetAccessTokenUseCase _setToken;

  LoginState _state;
  LoginState get state => _state;
  bool _disposed = false;

  /// The login page comes from the server, which issues a fresh one each time.
  Future<void> _loadUrl(GetLoginUrlUseCase getLoginUrl) async {
    try {
      _emit(_state.copyWith(loginUrl: await getLoginUrl(account)));
    } catch (e) {
      _emit(_state.copyWith(error: e.toString()));
    }
  }

  /// Returns true once a session is stored.
  /// Without a redirect login (Groww) the input may be empty: the session is
  /// created from the day's approval on the broker's site.
  Future<bool> loginWithRedirect(String input) =>
      _run(input, () => _login(account, input), allowEmpty: !_state.redirectLogin);

  Future<bool> useAccessToken(String input) => _run(input, () => _setToken(account, input));

  Future<bool> _run(String input, Future<void> Function() action, {bool allowEmpty = false}) async {
    if ((input.trim().isEmpty && !allowEmpty) || _state.busy) return false;
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
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
