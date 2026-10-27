class LoginState {
  const LoginState({
    required this.loginUrl,
    required this.codeName,
    this.redirectLogin = true,
    this.busy = false,
    this.error,
  });

  final String loginUrl;

  /// Query parameter the broker puts in the redirect URL.
  final String codeName;

  /// False for brokers without a redirect login (Groww): the user approves
  /// access on the broker's site, and the input is an optional TOTP code.
  final bool redirectLogin;
  final bool busy;
  final String? error;

  LoginState copyWith({bool? busy, String? error, bool clearError = false}) => LoginState(
        loginUrl: loginUrl,
        codeName: codeName,
        redirectLogin: redirectLogin,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
      );
}
