class LoginState {
  const LoginState({this.creating = false, this.busy = false, this.error, this.notice});

  /// Creating a new login with an invite code, rather than signing in.
  final bool creating;
  final bool busy;
  final String? error;

  /// Why the user is here without having signed out, e.g. an expired session.
  final String? notice;

  LoginState copyWith({bool? creating, bool? busy, String? error, bool clearError = false}) => LoginState(
        creating: creating ?? this.creating,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
        notice: notice,
      );
}
