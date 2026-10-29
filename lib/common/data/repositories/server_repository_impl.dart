import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/server_session.dart';
import '../../domain/repositories/server_repository.dart';
import '../../error/exceptions.dart';
import '../../utils/reactive_cache.dart';
import '../datasources/local/secure_storage_datasource.dart';
import '../datasources/remote/nexora_server_api.dart';

class ServerRepositoryImpl implements ServerRepository {
  ServerRepositoryImpl._(this._http, this._storage, ServerSession? initial) : _cache = ReactiveCache(initial);

  static const _key = 'server_session_v1';

  final http.Client _http;
  final SecureStorageDataSource _storage;
  final ReactiveCache<ServerSession?> _cache;

  static Future<ServerRepositoryImpl> load(http.Client http, SecureStorageDataSource storage) async {
    final raw = await storage.readJson(_key);
    final session = raw is Map
        ? ServerSession(url: raw['url'] as String, token: raw['token'] as String, email: raw['email'] as String)
        : null;
    return ServerRepositoryImpl._(http, storage, session);
  }

  /// Names this device in the server's session list.
  static String get deviceName => 'NexoraApp on ${kIsWeb ? 'web' : defaultTargetPlatform.name}';

  @override
  ServerSession? get current => _cache.value;

  String? _endedReason;

  @override
  String? get endedReason => _endedReason;

  @override
  Stream<ServerSession?> watch() => _cache.watch();

  /// An API client for the signed-in server. When the server rejects the
  /// session's token, the session is forgotten, which signs the app out.
  NexoraServerApi api(ServerSession session) => NexoraServerApi(
        _http,
        baseUrl: session.url,
        token: session.token,
        onUnauthorized: () => unawaited(_expire(session)),
      );

  Future<void> _expire(ServerSession session) async {
    if (!identical(current, session)) return;
    _endedReason = 'Your session ended. Sign in again.';
    await _forget();
  }

  Future<void> _forget() async {
    _cache.value = null;
    await _storage.delete(_key);
  }

  @override
  Future<ServerSession> signIn({required String url, required String email, required String password}) =>
      _start(url, '/v1/auth/login', {'email': email.trim(), 'password': password, 'device': deviceName});

  @override
  Future<ServerSession> register({
    required String url,
    required String email,
    required String password,
    required String inviteCode,
  }) =>
      _start(url, '/v1/auth/register', {
        'email': email.trim(),
        'password': password,
        'signupCode': inviteCode.trim(),
        'device': deviceName,
      });

  Future<ServerSession> _start(String url, String path, Map<String, Object?> body) async {
    final baseUrl = NexoraServerApi.normalizeUrl(url);
    return _save(baseUrl, await NexoraServerApi(_http, baseUrl: baseUrl).post(path, body));
  }

  @override
  Future<ServerSession> changePassword({required String currentPassword, required String newPassword}) async {
    final session = current;
    if (session == null) throw ServerApiException('Sign in first.');
    final json = await NexoraServerApi(_http, baseUrl: session.url, token: session.token).post('/v1/auth/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'device': deviceName,
    });
    return _save(session.url, json);
  }

  /// Stores the session from a sign-in reply (`{ token, user }`).
  Future<ServerSession> _save(String baseUrl, Map<String, dynamic> json) async {
    final token = json['token'];
    final user = json['user'];
    if (token is! String || user is! Map) {
      throw ServerApiException('That address answered, but it isn\'t a nexora-backend server.');
    }
    final session = ServerSession(url: baseUrl, token: token, email: user['email'] as String);
    await _storage.writeJson(_key, {'url': session.url, 'token': session.token, 'email': session.email});
    _endedReason = null;
    _cache.value = session;
    return session;
  }

  @override
  Future<void> signOut() async {
    final session = current;
    if (session == null) return;
    try {
      await NexoraServerApi(_http, baseUrl: session.url, token: session.token).post('/v1/auth/logout');
    } on ServerApiException {
      // Already ended or unreachable: forgetting it here is what matters.
    }
    _endedReason = null;
    await _forget();
  }

  @override
  Future<String> serverIp() async {
    final session = current;
    if (session == null) throw ServerApiException('Connect to a server first.');
    final json = await api(session).get('/v1/server/ip');
    return json['ip'] as String;
  }
}
