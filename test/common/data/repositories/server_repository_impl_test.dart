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
  const phone = '+919876543210';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageDataSource(const FlutterSecureStorage());
  });

  FakeServer server() => FakeServer({
        'POST /v1/auth/otp/start': (_) => {'sent': true, 'expires_in_seconds': 240},
        'POST /v1/auth/otp/verify': (_) => {
              'token': 'T1',
              'user': {'id': 'u', 'phone': phone},
            },
        'POST /v1/auth/logout': (_) => http.Response('', 204),
        'GET /v1/server/ip': (_) => {'ip': '203.0.113.7', 'liveTrading': false},
      });

  Future<ServerRepositoryImpl> signedIn(FakeServer fake) async {
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await repo.verifyCode(url: 'https://srv.test', phone: phone, code: '123456');
    return repo;
  }

  test('asks the server to text a code, then signs in with it and remembers the session', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    expect(repo.current, isNull);
    final emitted = <String?>[];
    repo.watch().listen((s) => emitted.add(s?.phone));

    final sent = await repo.requestCode(url: 'https://srv.test/', phone: ' +919876543210 ');
    expect([sent.phone, sent.expiresIn, sent.resendIn], [phone, const Duration(minutes: 4), const Duration(seconds: 30)]);
    expect(fake.bodyOf('POST /v1/auth/otp/start'), {'phone': phone});
    expect(fake.requests.last.headers.containsKey('Authorization'), isFalse);

    await repo.requestCode(url: 'https://srv.test', phone: phone, signupCode: ' family ');
    expect(fake.bodyOf('POST /v1/auth/otp/start'), {'phone': phone, 'signupCode': 'family'});
    await repo.requestCode(url: 'https://srv.test', phone: phone, signupCode: '  ');
    expect(fake.bodyOf('POST /v1/auth/otp/start'), {'phone': phone});

    final session = await repo.verifyCode(url: 'https://srv.test/', phone: phone, code: ' 123456 ');
    expect([session.url, session.token, session.phone, session.phoneLabel],
        ['https://srv.test', 'T1', phone, '+91 98765 43210']);
    expect(fake.bodyOf('POST /v1/auth/otp/verify'), {
      'phone': phone,
      'code': '123456',
      'device': ServerRepositoryImpl.deviceName,
    });

    final reloaded = await ServerRepositoryImpl.load(fake.client, storage);
    expect(reloaded.current?.token, 'T1');
    expect(reloaded.current?.phone, phone);
    await pumpEventQueue();
    expect(emitted, [null, phone]);
  });

  test('assumes 5 minutes when the server leaves out the expiry', () async {
    final repo = await ServerRepositoryImpl.load(FakeServer({'POST /v1/auth/otp/start': (_) => {'sent': true}}).client, storage);
    final sent = await repo.requestCode(url: 'https://srv.test', phone: phone);
    expect([sent.expiresIn, sent.resendIn], [const Duration(minutes: 5), ServerRepositoryImpl.resendWait]);
  });

  test('passes on that a new number needs the invite code', () async {
    final repo = await ServerRepositoryImpl.load(
      FakeServer({
        'POST /v1/auth/otp/start': (_) =>
            http.Response('{"error":{"code":"not_registered","message":"Sign up first."}}', 404),
      }).client,
      storage,
    );
    await expectLater(repo.requestCode(url: 'https://srv.test', phone: phone),
        throwsA(isA<ServerApiException>().having((e) => e.code, 'code', 'not_registered')));
  });

  test('a wrong code is an error but signs nothing out', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    fake.routes['POST /v1/auth/otp/verify'] =
        (_) => http.Response('{"error":{"code":"unauthorized","message":"Wrong code. 4 tries left."}}', 401);
    await expectLater(repo.verifyCode(url: 'https://srv.test', phone: phone, code: '000000'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'Wrong code. 4 tries left.')));
    expect(repo.current, isNull);
    expect(repo.endedReason, isNull);
  });

  test('rejects replies that are not from nexora-backend', () async {
    final repo = await ServerRepositoryImpl.load(
      FakeServer({
        'POST /v1/auth/otp/start': (_) => {'hello': 1},
        'POST /v1/auth/otp/verify': (_) => {
              'token': 'T',
              'user': {'id': 'u', 'email': 'old@example.com'},
            },
      }).client,
      storage,
    );
    final notBackend = throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('isn\'t a nexora-backend')));
    await expectLater(repo.requestCode(url: 'https://srv.test', phone: phone), notBackend);
    await expectLater(repo.verifyCode(url: 'https://srv.test', phone: phone, code: '1'), notBackend);
    expect(repo.current, isNull);
  });

  test('drops an email session saved before phone sign-in', () async {
    FlutterSecureStorage.setMockInitialValues({
      'server_session_v1': '{"url":"https://srv.test","token":"old","email":"me@example.com"}',
    });
    final repo = await ServerRepositoryImpl.load(server().client, storage);
    expect(repo.current, isNull);
    expect(await storage.readJson('server_session_v1'), isNull);
  });

  test('looks up the server IP, and signs out even when the server is unreachable', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>()));
    await repo.signOut(); // nothing to do yet
    await repo.verifyCode(url: 'https://srv.test', phone: phone, code: '123456');
    expect(await repo.serverIp(), '203.0.113.7');
    expect(fake.requests.last.headers['Authorization'], 'Bearer T1');

    fake.routes['POST /v1/auth/logout'] = (_) => http.Response('{"error":{"message":"down"}}', 503);
    await repo.signOut();
    expect(repo.current, isNull);
    expect(await storage.readJson('server_session_v2'), isNull);
  });

  test('forgets the session when the server rejects its token, and says why', () async {
    final fake = server();
    final repo = await signedIn(fake);
    final session = repo.current!;
    expect(repo.endedReason, isNull);

    fake.routes['GET /v1/server/ip'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>()));
    await pumpEventQueue();
    expect(repo.current, isNull);
    expect(repo.endedReason, 'Your session ended. Sign in again.');
    expect(await storage.readJson('server_session_v2'), isNull);

    // A late 401 from an old session doesn't touch a newer one.
    await repo.verifyCode(url: 'https://srv.test', phone: phone, code: '123456');
    expect(repo.endedReason, isNull);
    await expectLater(repo.api(session).get('/v1/server/ip'), throwsA(isA<ServerApiException>()));
    await pumpEventQueue();
    expect(repo.current, isNotNull);
  });

  test('a rejected sign-out still signs out, without an expiry notice', () async {
    final fake = server();
    final repo = await signedIn(fake);
    fake.routes['POST /v1/auth/logout'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    await repo.signOut();
    await pumpEventQueue();
    expect(repo.current, isNull);
    expect(repo.endedReason, isNull);
  });

  test('names the device by platform', () {
    expect(ServerRepositoryImpl.deviceName, 'NexoraApp on ${defaultTargetPlatform.name}');
  });
}
