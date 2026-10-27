import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/accounts/model/login_redirect.dart';

import '../../../fakes.dart';

void main() {
  group('forAccount', () {
    test('Zerodha looks for request_token anywhere', () {
      final r = LoginRedirect.forAccount(testAccount())!;
      expect(r.codeParam, 'request_token');
      expect(r.redirectUri, isNull);
    });

    test('Upstox uses its code parameter and the account redirect URI', () {
      final r = LoginRedirect.forAccount(
          testAccount().copyWith(broker: BrokerType.upstox, redirectUri: ' https://127.0.0.1/ '))!;
      expect(r.codeParam, 'code');
      expect(r.redirectUri, 'https://127.0.0.1/');
      expect(LoginRedirect.forAccount(testAccount().copyWith(broker: BrokerType.upstox))!.redirectUri, isNull);
    });

    test('Groww has no redirect login', () {
      expect(LoginRedirect.forAccount(testAccount().copyWith(broker: BrokerType.groww)), isNull);
    });
  });

  group('matches', () {
    const kite = LoginRedirect(codeParam: 'request_token');
    const upstox = LoginRedirect(codeParam: 'code', redirectUri: 'https://127.0.0.1/');

    test('without a redirect URI, any address carrying the code parameter', () {
      expect(kite.matches('https://127.0.0.1/?action=login&status=success&request_token=abc'), isTrue);
      expect(kite.matches('https://example.com/cb?request_token=abc'), isTrue);
      expect(kite.matches('https://kite.zerodha.com/connect/login?v=3&api_key=k'), isFalse);
      expect(kite.matches('https://127.0.0.1/?request_token='), isFalse, reason: 'empty code');
    });

    test('with a redirect URI, only that address (trailing slash and query ignored)', () {
      expect(upstox.matches('https://127.0.0.1/?code=abc'), isTrue);
      expect(upstox.matches('https://127.0.0.1?code=abc'), isTrue);
      expect(upstox.matches('https://127.0.0.1/?error=access_denied'), isTrue, reason: 'errors end the login too');
      expect(upstox.matches('https://api.upstox.com/v2/login/authorization/dialog?code=abc'), isFalse);
      expect(upstox.matches('http://127.0.0.1/?code=abc'), isFalse, reason: 'scheme must match');
      expect(upstox.matches('https://127.0.0.1:8443/?code=abc'), isFalse, reason: 'port must match');
      expect(upstox.matches('https://127.0.0.1/other?code=abc'), isFalse, reason: 'path must match');
    });

    test('a redirect URI with a path matches that path', () {
      const r = LoginRedirect(codeParam: 'code', redirectUri: 'https://my.site/upstox/callback');
      expect(r.matches('https://my.site/upstox/callback/?code=x'), isTrue);
      expect(r.matches('https://my.site/upstox?code=x'), isFalse);
    });

    test('relative or invalid addresses never match', () {
      expect(kite.matches('/?request_token=abc'), isFalse);
      expect(kite.matches('http://[::1'), isFalse);
      expect(const LoginRedirect(codeParam: 'code', redirectUri: 'not a url').matches('https://x/?code=1'), isTrue,
          reason: 'an unusable redirect URI falls back to the code parameter');
    });
  });
}
