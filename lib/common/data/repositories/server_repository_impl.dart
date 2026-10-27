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

  @override
  Stream<ServerSession?> watch() => _cache.watch();

  /// An API client for the signed-in server.
  NexoraServerApi api(ServerSession session) => NexoraServerApi(_http, baseUrl: session.url, token: session.token);

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
    final json = await NexoraServerApi(_http, baseUrl: baseUrl).post(path, body);
    final token = json['token'];
    final user = json['user'];
    if (token is! String || user is! Map) {
      throw ServerApiException('That address answered, but it isn\'t a nexora-backend server.');
    }
    final session = ServerSession(url: baseUrl, token: token, email: user['email'] as String);
    await _storage.writeJson(_key, {'url': session.url, 'token': session.token, 'email': session.email});
    _cache.value = session;
    return session;
  }

  @override
  Future<void> signOut() async {
    final session = current;
    if (session == null) return;
    try {
      await api(session).post('/v1/auth/logout');
    } on ServerApiException {
      // Already ended or unreachable: forgetting it here is what matters.
    }
    await _storage.delete(_key);
    _cache.value = null;
  }

  @override
  Future<String> serverIp() async {
    final session = current;
    if (session == null) throw ServerApiException('Connect to a server first.');
    final json = await api(session).get('/v1/server/ip');
    return json['ip'] as String;
  }
}
