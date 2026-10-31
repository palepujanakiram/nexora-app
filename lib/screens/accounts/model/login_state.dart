class LoginState {
  const LoginState({
    required this.loginUrl,
    required this.codeName,
    this.redirectLogin = true,
    this.acceptsAccessToken = true,
    this.loginFinishesOnServer = false,
    this.busy = false,
    this.waiting = false,
    this.error,
  });

  /// Empty until it has loaded (and for paper accounts on a server).
  final String loginUrl;

  /// Query parameter the broker puts in the redirect URL.
  final String codeName;

  /// False for brokers without a redirect login (Groww): the user approves
  /// access on the broker's site, and the input is an optional TOTP code.
  final bool redirectLogin;

  /// False when a server holds the broker tokens.
  final bool acceptsAccessToken;

  /// True when the broker redirects to the server, which finishes the login:
  /// the app opens the login page and waits ([waiting]).
  final bool loginFinishesOnServer;
  final bool busy;

  /// Waiting for the server to report the login finished.
  final bool waiting;
  final String? error;

  LoginState copyWith({String? loginUrl, bool? busy, bool? waiting, String? error, bool clearError = false}) =>
      LoginState(
        loginUrl: loginUrl ?? this.loginUrl,
        codeName: codeName,
        redirectLogin: redirectLogin,
        acceptsAccessToken: acceptsAccessToken,
        loginFinishesOnServer: loginFinishesOnServer,
        busy: busy ?? this.busy,
        waiting: waiting ?? this.waiting,
        error: clearError ? null : error ?? this.error,
      );
}
