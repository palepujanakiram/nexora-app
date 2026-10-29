import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/nexora_server_api.dart';
import 'package:nexora_app/common/error/exceptions.dart';

void main() {
  group('normalizeUrl', () {
    test('trims and drops trailing slashes', () {
      expect(NexoraServerApi.normalizeUrl('  https://nexora.fly.dev//  '), 'https://nexora.fly.dev');
    });

    test('allows plain http only for this machine or the local network', () {
      for (final url in ['http://localhost:8080', 'http://127.0.0.1:8080', 'http://10.0.2.2:8080', 'http://192.168.1.5:8080']) {
        expect(NexoraServerApi.normalizeUrl(url), url);
      }
      expect(() => NexoraServerApi.normalizeUrl('http://nexora.fly.dev'),
          throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'Use an https:// address for the server.')));
    });

    test('rejects text that is not an address', () {
      for (final url in ['', 'nexora.fly.dev', 'https://']) {
        expect(() => NexoraServerApi.normalizeUrl(url),
            throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('Enter the server address'))));
      }
    });
  });

  group('requests', () {
    late List<http.Request> requests;

    NexoraServerApi api(http.Response Function(http.Request) respond, {String? token = 'tok'}) {
      requests = [];
      return NexoraServerApi(
        MockClient((req) async {
          requests.add(req);
          return respond(req);
        }),
        baseUrl: 'https://srv.test',
        token: token,
      );
    }

    test('sends JSON with the bearer token and returns the body', () async {
      final client = api((_) => http.Response('{"ok":true}', 200));
      expect(await client.post('/v1/x', {'a': 1}), {'ok': true});
      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'https://srv.test/v1/x');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(req.body), {'a': 1});
    });

    test('get, patch and delete use their methods; empty bodies decode as empty maps', () async {
      final client = api((_) => http.Response('', 204), token: null);
      expect(await client.get('/a'), isEmpty);
      expect(await client.patch('/b', {'x': true}), isEmpty);
      expect(await client.delete('/c'), isEmpty);
      expect(requests.map((r) => r.method), ['GET', 'PATCH', 'DELETE']);
      expect(requests.first.headers.containsKey('Authorization'), isFalse);
      expect(requests.first.headers.containsKey('Content-Type'), isFalse);
    });

    test('turns server errors into ServerApiException with code and status', () async {
      final client = api((_) => http.Response(
            '{"error":{"code":"unauthorized","message":"Your session has ended. Sign in again."}}',
            401,
          ));
      await expectLater(
        client.get('/v1/me'),
        throwsA(isA<ServerApiException>()
            .having((e) => e.message, 'message', 'Your session has ended. Sign in again.')
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.code, 'code', 'unauthorized')
            .having((e) => e.toString(), 'toString', 'Your session has ended. Sign in again.')),
      );
    });

    test('explains errors without a message, non-JSON replies and non-object JSON', () async {
      await expectLater(api((_) => http.Response('{}', 500)).get('/x'),
          throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'The server returned HTTP 500.')));
      await expectLater(
          api((_) => http.Response('<html>', 200)).get('/x'),
          throwsA(isA<ServerApiException>()
              .having((e) => e.message, 'message', contains('isn\'t a nexora-backend server (HTTP 200)'))));
      expect(await api((_) => http.Response('[1,2]', 200)).get('/x'), isEmpty);
    });

    test('reports a rejected token, but not a failed sign-in without one', () async {
      var rejected = 0;
      final unauthorized = MockClient((_) async => http.Response('{"error":{"message":"Sign in again."}}', 401));
      final signedIn = NexoraServerApi(unauthorized, baseUrl: 'https://srv.test', token: 't', onUnauthorized: () => rejected++);
      await expectLater(signedIn.get('/x'), throwsA(isA<ServerApiException>()));
      expect(rejected, 1);

      final signingIn = NexoraServerApi(unauthorized, baseUrl: 'https://srv.test', onUnauthorized: () => rejected++);
      await expectLater(signingIn.post('/v1/auth/login', {}), throwsA(isA<ServerApiException>()));
      final forbidden = NexoraServerApi(MockClient((_) async => http.Response('{}', 403)),
          baseUrl: 'https://srv.test', token: 't', onUnauthorized: () => rejected++);
      await expectLater(forbidden.get('/x'), throwsA(isA<ServerApiException>()));
      expect(rejected, 1);
    });

    test('explains an unreachable server', () async {
      final client = NexoraServerApi(MockClient((_) => throw const SocketLikeException()), baseUrl: 'https://srv.test');
      await expectLater(
          client.get('/x'),
          throwsA(isA<ServerApiException>()
              .having((e) => e.message, 'message', contains('Couldn\'t reach the server at https://srv.test'))
              .having((e) => e.statusCode, 'status', isNull)));
    });

    test('gives up after the timeout', () async {
      final never = Completer<http.Response>();
      final client = NexoraServerApi(MockClient((_) => never.future),
          baseUrl: 'https://srv.test', timeout: const Duration(milliseconds: 10));
      await expectLater(client.get('/x'),
          throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('took too long'))));
    });
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
