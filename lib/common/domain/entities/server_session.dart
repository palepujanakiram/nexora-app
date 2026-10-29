/// A signed-in connection to a nexora-backend server. While one exists, the
/// app's accounts, broker logins, orders and activity live on that server, so
/// every device shares them and orders leave from the server's static IP.
class ServerSession {
  const ServerSession({required this.url, required this.token, required this.email});

  /// The server the login screen starts with. Override at build time with
  /// `--dart-define=NEXORA_SERVER_URL=https://…`.
  static const defaultUrl = String.fromEnvironment('NEXORA_SERVER_URL', defaultValue: 'https://nexora-backend-jp.fly.dev');

  /// Base URL without a trailing slash, e.g. `https://nexora.fly.dev`.
  final String url;

  /// Bearer token for this device. Stored only in secure storage.
  final String token;
  final String email;
}
