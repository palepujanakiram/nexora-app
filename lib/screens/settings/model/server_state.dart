import '../../../common/domain/entities/server_session.dart';

class ServerState {
  const ServerState({this.session, this.busy = false, this.error, this.serverIp, this.loadingIp = false});

  /// Null while the app works on its own.
  final ServerSession? session;
  final bool busy;
  final String? error;

  /// The server's outgoing IP, once looked up.
  final String? serverIp;
  final bool loadingIp;

  bool get connected => session != null;

  ServerState copyWith({
    ServerSession? session,
    bool clearSession = false,
    bool? busy,
    String? error,
    bool clearError = false,
    String? serverIp,
    bool clearServerIp = false,
    bool? loadingIp,
  }) =>
      ServerState(
        session: clearSession ? null : session ?? this.session,
        busy: busy ?? this.busy,
        error: clearError ? null : error ?? this.error,
        serverIp: clearServerIp ? null : serverIp ?? this.serverIp,
        loadingIp: loadingIp ?? this.loadingIp,
      );
}
