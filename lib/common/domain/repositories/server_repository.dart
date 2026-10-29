import '../entities/server_session.dart';

/// Switches where accounts, logins, orders and activity live: on the server
/// for [session], or on this device when it's null.
typedef SwitchDataSource = Future<void> Function(ServerSession? session);

/// Signing this device in to (and out of) a nexora-backend server.
abstract interface class ServerRepository {
  /// The current session, or null when signed out.
  ServerSession? get current;

  /// Why the last session ended without the user signing out (the server
  /// rejected its token), or null. Cleared by the next sign-in.
  String? get endedReason;

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

  /// Changes the password. The server signs out every device, then starts a
  /// new session for this one.
  Future<ServerSession> changePassword({required String currentPassword, required String newPassword});

  /// The public IP the server's orders come from: the one to register with brokers.
  Future<String> serverIp();
}
