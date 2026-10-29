import '../entities/server_session.dart';
import '../entities/sign_in_code.dart';

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

  /// Asks the server at [url] to text a sign-in code to [phone]. For a number
  /// with no login, the server refuses with the `not_registered` error code
  /// and sends nothing.
  Future<SignInCode> requestCode({required String url, required String phone});

  /// Signs in with the [code] texted to [phone] (as [SignInCode.phone]).
  Future<ServerSession> verifyCode({required String url, required String phone, required String code});

  /// Ends the session on the server (best effort) and forgets it here.
  Future<void> signOut();

  /// The public IP the server's orders come from: the one to register with brokers.
  Future<String> serverIp();
}
