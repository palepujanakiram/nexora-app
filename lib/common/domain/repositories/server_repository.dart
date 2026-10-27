import '../entities/server_session.dart';

/// Switches where accounts, logins, orders and activity live: on the server
/// for [session], or on this device when it's null.
typedef SwitchDataSource = Future<void> Function(ServerSession? session);

/// Signing this device in to (and out of) a nexora-backend server.
abstract interface class ServerRepository {
  /// The current session, or null when the app works on its own.
  ServerSession? get current;

  /// Emits the current session, then every change.
  Stream<ServerSession?> watch();

  Future<ServerSession> signIn({required String url, required String email, required String password});

  /// Creates a user on the server with the owner's invite code.
  Future<ServerSession> register({
    required String url,
    required String email,
    required String password,
    required String inviteCode,
  });

  /// Ends the session on the server (best effort) and forgets it here.
  Future<void> signOut();

  /// The public IP the server's orders come from: the one to register with brokers.
  Future<String> serverIp();
}
