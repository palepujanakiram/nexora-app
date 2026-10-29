import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexora_app/common/data/datasources/local/secure_storage_datasource.dart';
import 'package:nexora_app/common/data/repositories/server_repository_impl.dart';
import 'package:nexora_app/common/error/exceptions.dart';

import 'server/fake_server.dart';

void main() {
  late SecureStorageDataSource storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageDataSource(const FlutterSecureStorage());
  });

  FakeServer server() => FakeServer({
        'POST /v1/auth/login': (_) => {
              'token': 'T1',
              'user': {'id': 'u', 'email': 'me@example.com'},
            },
        'POST /v1/auth/register': (_) => {
              'token': 'T2',
              'user': {'id': 'u', 'email': 'new@example.com'},
            },
        'POST /v1/auth/logout': (_) => http.Response('', 204),
        'GET /v1/server/ip': (_) => {'ip': '203.0.113.7', 'liveTrading': false},
        'POST /v1/auth/password': (_) => {
              'token': 'T3',
              'user': {'id': 'u', 'email': 'me@example.com'},
            },
      });

  test('starts signed out, signs in, remembers the session and reloads it', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    expect(repo.current, isNull);
    final emitted = <String?>[];
    repo.watch().listen((s) => emitted.add(s?.email));

    final session = await repo.signIn(url: 'https://srv.test/', email: ' me@example.com ', password: 'pw');
    expect([session.url, session.token, session.email], ['https://srv.test', 'T1', 'me@example.com']);
    expect(fake.bodyOf('POST /v1/auth/login'), {
      'email': 'me@example.com',
      'password': 'pw',
      'device': ServerRepositoryImpl.deviceName,
    });

    final reloaded = await ServerRepositoryImpl.load(fake.client, storage);
    expect(reloaded.current?.token, 'T1');
    await pumpEventQueue();
    expect(emitted, [null, 'me@example.com']);
  });

  test('registers with the invite code', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    final session = await repo.register(url: 'https://srv.test', email: 'new@example.com', password: 'pw', inviteCode: ' code ');
    expect(session.email, 'new@example.com');
    expect(fake.bodyOf('POST /v1/auth/register')['signupCode'], 'code');
  });

  test('rejects a reply that is not a sign-in', () async {
    final repo = await ServerRepositoryImpl.load(FakeServer({'POST /v1/auth/login': (_) => {'hello': 1}}).client, storage);
    await expectLater(repo.signIn(url: 'https://srv.test', email: 'a@b.c', password: 'pw'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('isn\'t a nexora-backend'))));
    expect(repo.current, isNull);
  });

  test('looks up the server IP, and signs out even when the server is unreachable', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>()));
    await repo.signOut(); // nothing to do yet
    await repo.signIn(url: 'https://srv.test', email: 'me@example.com', password: 'pw');
    expect(await repo.serverIp(), '203.0.113.7');
    expect(fake.requests.last.headers['Authorization'], 'Bearer T1');

    fake.routes['POST /v1/auth/logout'] = (_) => http.Response('{"error":{"message":"down"}}', 503);
    await repo.signOut();
    expect(repo.current, isNull);
    expect(await storage.readJson('server_session_v1'), isNull);
  });

  test('forgets the session when the server rejects its token, and says why', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    final session = await repo.signIn(url: 'https://srv.test', email: 'me@example.com', password: 'pw');
    expect(repo.endedReason, isNull);

    fake.routes['GET /v1/server/ip'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>()));
    await pumpEventQueue();
    expect(repo.current, isNull);
    expect(repo.endedReason, 'Your session ended. Sign in again.');
    expect(await storage.readJson('server_session_v1'), isNull);

    // A late 401 from an old session doesn't touch a newer one.
    await repo.signIn(url: 'https://srv.test', email: 'me@example.com', password: 'pw');
    expect(repo.endedReason, isNull);
    await expectLater(repo.api(session).get('/v1/server/ip'), throwsA(isA<ServerApiException>()));
    await pumpEventQueue();
    expect(repo.current, isNotNull);
  });

  test('a rejected sign-out still signs out, without an expiry notice', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await repo.signIn(url: 'https://srv.test', email: 'me@example.com', password: 'pw');
    fake.routes['POST /v1/auth/logout'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    await repo.signOut();
    await pumpEventQueue();
    expect(repo.current, isNull);
    expect(repo.endedReason, isNull);
  });

  test('changes the password and keeps the new session', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await expectLater(repo.changePassword(currentPassword: 'a', newPassword: 'b'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'Sign in first.')));

    await repo.signIn(url: 'https://srv.test', email: 'me@example.com', password: 'old password');
    final session = await repo.changePassword(currentPassword: 'old password', newPassword: 'new password');
    expect(session.token, 'T3');
    expect(repo.current, same(session));
    expect(fake.requests.last.headers['Authorization'], 'Bearer T1');
    expect(fake.bodyOf('POST /v1/auth/password'), {
      'currentPassword': 'old password',
      'newPassword': 'new password',
      'device': ServerRepositoryImpl.deviceName,
    });
    expect((await ServerRepositoryImpl.load(fake.client, storage)).current?.token, 'T3');

    // A wrong current password is a 401 too, but must not sign the user out.
    fake.routes['POST /v1/auth/password'] =
        (_) => http.Response('{"error":{"code":"unauthorized","message":"Current password is wrong."}}', 401);
    await expectLater(repo.changePassword(currentPassword: 'x', newPassword: 'new password 2'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'Current password is wrong.')));
    await pumpEventQueue();
    expect(repo.current?.token, 'T3');
  });

  test('names the device by platform', () {
    expect(ServerRepositoryImpl.deviceName, 'NexoraApp on ${defaultTargetPlatform.name}');
  });
}
