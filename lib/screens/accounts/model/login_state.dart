class LoginState {
  const LoginState({required this.loginUrl, required this.codeName, this.busy = false, this.error});

  final String loginUrl;

  /// Query parameter the broker puts in the redirect URL.
  final String codeName;
  final bool busy;
  final String? error;

  LoginState copyWith({bool? busy, String? error, bool clearError = false}) => LoginState(
        loginUrl: loginUrl,
        codeName: codeName,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
      );
}
