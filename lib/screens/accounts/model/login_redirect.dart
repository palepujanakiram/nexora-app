import '../../../common/domain/entities/broker_account.dart';

/// Recognises the broker's redirect back after login, so an in-app browser can
/// catch it instead of the user copying the address by hand.
class LoginRedirect {
  const LoginRedirect({required this.codeParam, this.redirectUri});

  /// Query parameter that carries the one-time login code.
  final String codeParam;

  /// The redirect URL registered with the broker, when the app knows it.
  /// Without it, any address carrying [codeParam] counts as the redirect.
  final String? redirectUri;

  /// Zerodha redirects with `request_token`, Upstox with `code` to the
  /// account's redirect URI. Groww has no redirect login.
  static LoginRedirect? forAccount(BrokerAccount account) => switch (account.broker) {
        BrokerType.zerodha => const LoginRedirect(codeParam: 'request_token'),
        BrokerType.upstox => LoginRedirect(
            codeParam: 'code',
            redirectUri: account.redirectUri.trim().isEmpty ? null : account.redirectUri.trim(),
          ),
        BrokerType.groww => null,
      };

  /// Whether [url] is the redirect that ends the login.
  bool matches(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final redirect = redirectUri == null ? null : Uri.tryParse(redirectUri!);
    if (redirect != null && redirect.hasScheme) {
      return uri.scheme == redirect.scheme &&
          uri.host == redirect.host &&
          uri.port == redirect.port &&
          _path(uri) == _path(redirect);
    }
    return (uri.queryParameters[codeParam] ?? '').isNotEmpty;
  }

  static String _path(Uri uri) => uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
}
