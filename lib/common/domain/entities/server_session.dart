/// A signed-in connection to a nexora-backend server. While one exists, the
/// app's accounts, broker logins, orders and activity live on that server, so
/// every device shares them and orders leave from the server's static IP.
class ServerSession {
  const ServerSession({required this.url, required this.token, required this.phone, this.refreshToken = ''});

  /// The server the login screen starts with. Override at build time with
  /// `--dart-define=NEXORA_SERVER_URL=https://…`.
  static const defaultUrl = String.fromEnvironment('NEXORA_SERVER_URL', defaultValue: 'https://nexora-backend-jp.fly.dev');

  /// Base URL without a trailing slash, e.g. `https://nexora.fly.dev`.
  final String url;

  /// Short-lived bearer (access) token for this device. Stored only in
  /// secure storage.
  final String token;

  /// Gets a new [token] when it expires; rotates on every use. Stored only in
  /// secure storage.
  final String refreshToken;

  /// The signed-in mobile number in E.164, e.g. `+919876543210`.
  final String phone;

  String get phoneLabel => formatPhone(phone);
}

/// `+919876543210` → `+91 98765 43210`. Other numbers are shown as they are.
String formatPhone(String e164) {
  final m = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(e164);
  return m == null ? e164 : '+91 ${m[1]} ${m[2]}';
}
