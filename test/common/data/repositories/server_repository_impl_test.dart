import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexora_app/common/data/datasources/local/secure_storage_datasource.dart';
import 'package:nexora_app/common/data/repositories/server_repository_impl.dart';
import 'package:nexora_app/common/domain/entities/sign_up_details.dart';
import 'package:nexora_app/common/error/exceptions.dart';

import 'server/fake_server.dart';

void main() {
  late SecureStorageDataSource storage;
  const phone = '+919876543210';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageDataSource(const FlutterSecureStorage());
  });

  Map<String, Object?> tokens(int n) => {
        'accessToken': 'A$n',
        'tokenType': 'Bearer',
        'expiresIn': 900,
        'refreshToken': 'R$n',
        'refreshExpiresAt': '2026-11-29T04:00:00.000Z',
        'sessionId': 'ses_1',
      };

  /// A server whose access tokens are accepted only when current, and whose
  /// refresh tokens rotate on every use.
  FakeServer server() {
    var issued = 1;
    bool current(http.Request req) => req.headers['Authorization'] == 'Bearer A$issued';
    http.Response expired() => http.Response('{"error":{"code":"unauthorized","message":"Token expired."}}', 401);
    return FakeServer({
      'POST /auth/otp/request': (_) => {'sent': true, 'expiresInSeconds': 240},
      'POST /auth/otp/verify': (_) => {
            ...tokens(issued = 1),
            'user': {'id': 'usr_1', 'phone': phone, 'email': null, 'createdAt': '2026-10-30T04:00:00.000Z'},
          },
      'POST /auth/refresh': (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['refreshToken'] != 'R$issued') {
          return http.Response('{"error":{"code":"refresh_reused","message":"Signed out."}}', 401);
        }
        return tokens(++issued);
      },
      'POST /auth/logout': (req) => current(req) ? http.Response('', 204) : expired(),
      'GET /server/ip': (req) => current(req) ? {'ip': '203.0.113.7', 'liveTrading': false} : expired(),
      'GET /me': (req) => current(req) ? {'id': 'usr_1'} : expired(),
    });
  }

  Future<ServerRepositoryImpl> signedIn(FakeServer fake) async {
    final repo = await ServerRepositoryImpl.load(fake.client, storage, clientId: 'cl_test');
    await repo.verifyCode(url: 'https://srv.test', phone: phone, code: '123456');
    return repo;
  }

  test('asks the server to text a code, then signs in as this client and remembers the session', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage, clientId: 'cl_test');
    expect(repo.current, isNull);
    final emitted = <String?>[];
    repo.watch().listen((s) => emitted.add(s?.phone));

    final sent = await repo.requestCode(url: 'https://srv.test/', phone: ' +919876543210 ');
    expect([sent.phone, sent.expiresIn, sent.resendIn], [phone, const Duration(minutes: 4), const Duration(seconds: 30)]);
    expect(fake.bodyOf('POST /auth/otp/request'), {'phone': phone});
    expect(fake.requests.last.headers.containsKey('Authorization'), isFalse);

    final session = await repo.verifyCode(url: 'https://srv.test/', phone: phone, code: ' 123456 ');
    expect([session.url, session.token, session.refreshToken, session.phone, session.phoneLabel],
        ['https://srv.test', 'A1', 'R1', phone, '+91 98765 43210']);
    expect(fake.bodyOf('POST /auth/otp/verify'), {
      'phone': phone,
      'code': '123456',
      'clientId': 'cl_test',
      'device': ServerRepositoryImpl.deviceName,
    });

    final reloaded = await ServerRepositoryImpl.load(fake.client, storage);
    expect([reloaded.current?.token, reloaded.current?.refreshToken, reloaded.current?.phone], ['A1', 'R1', phone]);
    await pumpEventQueue();
    expect(emitted, [null, phone]);
  });

  test('signs up: texts a sign-up code for the form, then creates the account and signs in', () async {
    final fake = server();
    fake.routes['POST /auth/signup/request'] = (_) => {'sent': true, 'expiresInSeconds': 300};
    fake.routes['POST /auth/signup/verify'] = (_) => http.Response(
        jsonEncode({
          ...tokens(7),
          'user': {'id': 'usr_2', 'phone': phone, 'email': 'ravi@example.com', 'fullName': 'Ravi Kumar'},
        }),
        201);
    final repo = await ServerRepositoryImpl.load(fake.client, storage, clientId: 'cl_test');
    const details = SignUpDetails(
      fullName: ' Ravi Kumar ',
      email: ' ravi@example.com ',
      acceptsTerms: true,
      acceptsRisk: true,
      acceptsDataUse: true,
    );
    final form = {
      'phone': phone,
      'fullName': 'Ravi Kumar',
      'email': 'ravi@example.com',
      'consents': {'terms': true, 'risk': true, 'dataUse': true},
    };

    final sent = await repo.requestSignUpCode(url: 'https://srv.test/', phone: ' $phone ', details: details);
    expect([sent.phone, sent.expiresIn, sent.resendIn], [phone, const Duration(minutes: 5), ServerRepositoryImpl.resendWait]);
    expect(fake.bodyOf('POST /auth/signup/request'), form);

    final session = await repo.verifySignUp(url: 'https://srv.test', phone: phone, details: details, code: ' 654321 ');
    expect([session.url, session.token, session.refreshToken, session.phone], ['https://srv.test', 'A7', 'R7', phone]);
    expect(fake.bodyOf('POST /auth/signup/verify'), {
      ...form,
      'code': '654321',
      'clientId': 'cl_test',
      'device': ServerRepositoryImpl.deviceName,
    });
    expect(repo.current?.token, 'A7');
    expect((await ServerRepositoryImpl.load(fake.client, storage)).current?.phone, phone, reason: 'remembered');
  });

  test('a number that already has an account is refused with its code, and nothing is signed in', () async {
    final fake = server();
    fake.routes['POST /auth/signup/verify'] = (_) => http.Response(
        '{"error":{"code":"already_registered","message":"This mobile number already has an account. Sign in instead."}}',
        409);
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await expectLater(
      repo.verifySignUp(
          url: 'https://srv.test', phone: phone, details: const SignUpDetails(fullName: 'A', email: 'a@b.co'), code: '1'),
      throwsA(isA<ServerApiException>()
          .having((e) => e.code, 'code', 'already_registered')
          .having((e) => e.statusCode, 'statusCode', 409)),
    );
    expect(repo.current, isNull);
  });

  test('a sign-up code request that is not from a nexora-backend server is an error', () async {
    final repo = await ServerRepositoryImpl.load(
        FakeServer({'POST /auth/signup/request': (_) => {'hello': 1}}).client, storage);
    await expectLater(
      repo.requestSignUpCode(url: 'https://srv.test', phone: phone, details: const SignUpDetails(fullName: 'A', email: 'e')),
      throwsA(isA<ServerApiException>()),
    );
  });

  test('assumes 5 minutes when the server leaves out the expiry', () async {
    final repo = await ServerRepositoryImpl.load(FakeServer({'POST /auth/otp/request': (_) => {'sent': true}}).client, storage);
    final sent = await repo.requestCode(url: 'https://srv.test', phone: phone);
    expect([sent.expiresIn, sent.resendIn], [const Duration(minutes: 5), ServerRepositoryImpl.resendWait]);
  });

  test('each platform signs in as its own client', () {
    expect(ServerRepositoryImpl.clientIdFor(true, TargetPlatform.iOS), 'cl_4o_-efohcNv0XMiM');
    expect(ServerRepositoryImpl.clientIdFor(false, TargetPlatform.iOS), 'cl_Gw8NtirNcIdxf5o3');
    expect(ServerRepositoryImpl.clientIdFor(false, TargetPlatform.macOS), 'cl_Gw8NtirNcIdxf5o3');
    expect(ServerRepositoryImpl.clientIdFor(false, TargetPlatform.android), 'cl_WMQcVwaZ9RvD-bzp');
  });

  test('a wrong code is an error but signs nothing out', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    fake.routes['POST /auth/otp/verify'] =
        (_) => http.Response('{"error":{"code":"otp_invalid","message":"Wrong code. 4 tries left."}}', 401);
    await expectLater(repo.verifyCode(url: 'https://srv.test', phone: phone, code: '000000'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'Wrong code. 4 tries left.')));
    expect(repo.current, isNull);
    expect(repo.endedReason, isNull);
  });

  test('rejects replies that are not from nexora-backend', () async {
    final fake = FakeServer({
      'POST /auth/otp/request': (_) => {'hello': 1},
      'POST /auth/otp/verify': (_) => {
            'token': 'T',
            'user': {'id': 'u', 'email': 'old@example.com'},
          },
    });
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    final notBackend = throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('isn\'t a nexora-backend')));
    await expectLater(repo.requestCode(url: 'https://srv.test', phone: phone), notBackend);
    await expectLater(repo.verifyCode(url: 'https://srv.test', phone: phone, code: '1'), notBackend);
    fake.routes['POST /auth/otp/verify'] = (_) => {
          'token': 'T',
          'user': {'phone': phone},
        };
    await expectLater(repo.verifyCode(url: 'https://srv.test', phone: phone, code: '1'), notBackend);
    expect(repo.current, isNull);
  });

  test('drops sessions saved for the old /v1 server', () async {
    FlutterSecureStorage.setMockInitialValues({
      'server_session_v1': '{"url":"https://srv.test","token":"old","email":"me@example.com"}',
      'server_session_v2': '{"url":"https://srv.test","token":"old","phone":"+919876543210"}',
    });
    final repo = await ServerRepositoryImpl.load(server().client, storage);
    expect(repo.current, isNull);
    expect(await storage.readJson('server_session_v1'), isNull);
    expect(await storage.readJson('server_session_v2'), isNull);
  });

  test('looks up the server IP, and signs out even when the server is unreachable', () async {
    final fake = server();
    final repo = await ServerRepositoryImpl.load(fake.client, storage);
    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>()));
    await repo.signOut(); // nothing to do yet
    await repo.verifyCode(url: 'https://srv.test', phone: phone, code: '123456');
    expect(await repo.serverIp(), '203.0.113.7');
    expect(fake.requests.last.headers['Authorization'], 'Bearer A1');

    fake.routes['POST /auth/logout'] = (_) => http.Response('{"error":{"message":"down"}}', 503);
    await repo.signOut();
    expect(repo.current, isNull);
    expect(await storage.readJson('server_session_v3'), isNull);
  });

  test('renews an expired access token with the refresh token, once for parallel requests', () async {
    final fake = server();
    final repo = await signedIn(fake);
    final api = repo.api(repo.current!);
    final emitted = <String?>[];
    repo.watch().listen((s) => emitted.add(s?.token));

    // The server moves on: A1 no longer works, R1 still does.
    fake.routes['GET /me'] = (req) => req.headers['Authorization'] == 'Bearer A2'
        ? {'id': 'usr_1'}
        : http.Response('{"error":{"code":"unauthorized","message":"Token expired."}}', 401);
    final results = await Future.wait([api.get('/me'), api.get('/me')]);
    expect(results, everyElement({'id': 'usr_1'}));
    expect(fake.requests.where((r) => r.url.path == '/auth/refresh'), hasLength(1));
    expect(fake.bodyOf('POST /auth/refresh'), {'refreshToken': 'R1', 'clientId': 'cl_test'});
    expect([repo.current?.token, repo.current?.refreshToken], ['A2', 'R2']);
    expect((await storage.readJson('server_session_v3') as Map)['refreshToken'], 'R2');

    // A client made for the older session token uses the latest one.
    expect(await repo.api(repo.current!).get('/me'), {'id': 'usr_1'});
    await pumpEventQueue();
    expect(emitted.last, 'A2');
    expect(repo.endedReason, isNull);
  });

  test('forgets the session when it can\'t be renewed, and says why', () async {
    final fake = server();
    final repo = await signedIn(fake);
    fake.routes['GET /server/ip'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    fake.routes['POST /auth/refresh'] =
        (_) => http.Response('{"error":{"code":"refresh_reused","message":"Signed out."}}', 401);

    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>()));
    expect(repo.current, isNull);
    expect(repo.endedReason, 'Your session ended. Sign in again.');
    expect(await storage.readJson('server_session_v3'), isNull);

    // Signing in again clears the notice.
    await repo.verifyCode(url: 'https://srv.test', phone: phone, code: '123456');
    expect(repo.endedReason, isNull);
    expect(repo.current, isNotNull);
  });

  test('a client for a session that has since ended doesn\'t renew', () async {
    final fake = server();
    final repo = await signedIn(fake);
    final api = repo.api(repo.current!);
    await repo.signOut();
    fake.routes['GET /me'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    await expectLater(api.get('/me'), throwsA(isA<ServerApiException>()));
    expect(fake.requests.where((r) => r.url.path == '/auth/refresh'), isEmpty);
  });

  test('keeps the session when the server can\'t be reached to renew it', () async {
    final fake = server();
    final repo = await signedIn(fake);
    fake.routes['GET /server/ip'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    fake.routes['POST /auth/refresh'] = (_) => http.Response('{"error":{"message":"down"}}', 503);
    await expectLater(repo.serverIp(), throwsA(isA<ServerApiException>().having((e) => e.message, 'm', 'down')));
    expect(repo.current?.token, 'A1');
    expect(repo.endedReason, isNull);
  });

  test('a rejected sign-out still signs out, without an expiry notice', () async {
    final fake = server();
    final repo = await signedIn(fake);
    fake.routes['POST /auth/logout'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    fake.routes['POST /auth/refresh'] = (_) => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401);
    await repo.signOut();
    await pumpEventQueue();
    expect(repo.current, isNull);
    expect(repo.endedReason, isNull);
    expect(fake.last('POST /auth/logout').headers['Authorization'], 'Bearer A1');
  });

  test('names the device by platform', () {
    expect(ServerRepositoryImpl.deviceName, 'NexoraApp on ${defaultTargetPlatform.name}');
  });
}
