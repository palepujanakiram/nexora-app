import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/repositories/proxy_repository_impl.dart';
import 'package:nexora_app/common/domain/entities/proxy_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProxyRepositoryImpl repo(http.Response Function(http.Request) handler, [List<Uri>? seen]) =>
      ProxyRepositoryImpl(MockClient((req) async {
        seen?.add(req.url);
        return handler(req);
      }));

  http.Response health(Map<String, Object?> body) => http.Response(jsonEncode(body), 200);

  test('connected when the proxy accepts this origin; calls /health without double slashes', () async {
    final seen = <Uri>[];
    final h = await repo(
      (_) => health({'service': 'nexora-cors-proxy', 'originAllowed': true, 'ordersEnabled': false}),
      seen,
    ).check('https://p.workers.dev/');
    expect(h.status, ProxyHealthStatus.connected);
    expect(h.ordersEnabled, isFalse);
    expect(seen.single.toString(), 'https://p.workers.dev/health');
  });

  test('reports a rejected origin', () async {
    final h = await repo(
      (_) => health({'service': 'nexora-cors-proxy', 'originAllowed': false, 'origin': 'https://x.app'}),
    ).check('https://p.workers.dev');
    expect(h.status, ProxyHealthStatus.originNotAllowed);
    expect(h.origin, 'https://x.app');
  });

  test('something else at the URL is not a proxy', () async {
    expect((await repo((_) => http.Response('<html>', 200)).check('https://example.com')).status,
        ProxyHealthStatus.notAProxy);
    expect((await repo((_) => health({'hello': 'world'})).check('https://example.com')).status,
        ProxyHealthStatus.notAProxy);
  });

  test('network failures and bad URLs are unreachable', () async {
    final failing = repo((_) => throw http.ClientException('XMLHttpRequest error'));
    expect((await failing.check('https://p.workers.dev')).status, ProxyHealthStatus.unreachable);
    expect((await failing.check('')).status, ProxyHealthStatus.unreachable);
    expect((await failing.check('not a url')).status, ProxyHealthStatus.unreachable);
  });

  test('bundles the Cloudflare Worker code', () async {
    final script = await repo((_) => http.Response('', 200)).workerScript();
    expect(script, contains("service: 'nexora-cors-proxy'"));
    expect(script, contains('export default'));
  });
}
