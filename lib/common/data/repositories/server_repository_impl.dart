import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/server_session.dart';
import '../../domain/entities/sign_in_code.dart';
import '../../domain/repositories/server_repository.dart';
import '../../error/exceptions.dart';
import '../../utils/reactive_cache.dart';
import '../datasources/local/secure_storage_datasource.dart';
import '../datasources/remote/nexora_server_api.dart';

class ServerRepositoryImpl implements ServerRepository {
  ServerRepositoryImpl._(this._http, this._storage, this.clientId, ServerSession? initial)
    : _cache = ReactiveCache(initial);

  static const _key = 'server_session_v3';

  /// Sessions from the old `/v1` server (email, then phone). The new server
  /// doesn't know their tokens.
  static const _oldKeys = ['server_session_v1', 'server_session_v2'];

  final http.Client _http;
  final SecureStorageDataSource _storage;
  final ReactiveCache<ServerSession?> _cache;

  /// This build's client id on the server; see [clientIdFor].
  final String clientId;

  static Future<ServerRepositoryImpl> load(
    http.Client http,
    SecureStorageDataSource storage, {
    String? clientId,
  }) async {
    for (final old in _oldKeys) {
      await storage.delete(old);
    }
    final raw = await storage.readJson(_key);
    final session = raw is Map
        ? ServerSession(
            url: raw['url'] as String,
            token: raw['token'] as String,
            refreshToken: raw['refreshToken'] as String,
            phone: raw['phone'] as String,
          )
        : null;
    return ServerRepositoryImpl._(http, storage, clientId ?? clientIdFor(kIsWeb, defaultTargetPlatform), session);
  }

  /// Each platform's build is its own client on the server, with its own
  /// session length. Override with `--dart-define=NEXORA_CLIENT_ID=cl_…`.
  static String clientIdFor(bool web, TargetPlatform platform) {
    const override = String.fromEnvironment('NEXORA_CLIENT_ID');
    if (override.isNotEmpty) return override;
    if (web) return 'cl_4o_-efohcNv0XMiM';
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? 'cl_Gw8NtirNcIdxf5o3'
        : 'cl_WMQcVwaZ9RvD-bzp';
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

  /// An API client for the signed-in server. It renews the access token when
  /// it expires; when the session can't be renewed, the session is forgotten,
  /// which signs the app out.
  NexoraServerApi api(ServerSession session) =>
      NexoraServerApi(_http, baseUrl: session.url, auth: _SessionAuth(this, session));

  Future<String?>? _renewing;

  /// One renewal at a time: refresh tokens rotate, and sending a spent one
  /// again makes the server end the whole session.
  Future<String?> _renew(ServerSession session, String rejected) {
    final now = current;
    if (now == null || now.url != session.url || now.phone != session.phone) return Future.value(null);
    if (now.token != rejected) return Future.value(now.token);
    return _renewing ??= _refresh(now).whenComplete(() => _renewing = null);
  }

  Future<String?> _refresh(ServerSession session) async {
    final Map<String, dynamic> json;
    try {
      json = await NexoraServerApi(
        _http,
        baseUrl: session.url,
      ).post('/auth/refresh', {'refreshToken': session.refreshToken, 'clientId': clientId});
    } on ServerApiException catch (e) {
      // Unreachable: keep the session and let the request fail.
      if (e.statusCode == null || e.statusCode! >= 500) rethrow;
      _endedReason = 'Your session ended. Sign in again.';
      await _forget();
      return null;
    }
    return (await _save(session.url, json, phone: session.phone)).token;
  }

  Future<void> _forget() async {
    _cache.value = null;
    await _storage.delete(_key);
  }

  /// How long the app waits before offering to send another code.
  static const resendWait = Duration(seconds: 30);

  @override
  Future<SignInCode> requestCode({required String url, required String phone}) async {
    final baseUrl = NexoraServerApi.normalizeUrl(url);
    final json = await NexoraServerApi(_http, baseUrl: baseUrl).post('/auth/otp/request', {'phone': phone.trim()});
    if (json['sent'] != true) {
      throw ServerApiException('That address answered, but it isn\'t a nexora-backend server.');
    }
    return SignInCode(
      phone: phone.trim(),
      expiresIn: Duration(seconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300),
      resendIn: resendWait,
    );
  }

  @override
  Future<ServerSession> verifyCode({required String url, required String phone, required String code}) async {
    final baseUrl = NexoraServerApi.normalizeUrl(url);
    final json = await NexoraServerApi(
      _http,
      baseUrl: baseUrl,
    ).post('/auth/otp/verify', {'phone': phone, 'code': code.trim(), 'clientId': clientId, 'device': deviceName});
    final user = json['user'];
    final signedIn = user is Map ? user['phone'] : null;
    if (signedIn is! String) {
      throw ServerApiException('That address answered, but it isn\'t a nexora-backend server.');
    }
    final session = await _save(baseUrl, json, phone: signedIn);
    _endedReason = null;
    return session;
  }

  /// Stores the session from a token reply (`{ accessToken, refreshToken }`).
  Future<ServerSession> _save(String baseUrl, Map<String, dynamic> json, {required String phone}) async {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    if (access is! String || refresh is! String) {
      throw ServerApiException('That address answered, but it isn\'t a nexora-backend server.');
    }
    final session = ServerSession(url: baseUrl, token: access, refreshToken: refresh, phone: phone);
    await _storage.writeJson(_key, {
      'url': session.url,
      'token': session.token,
      'refreshToken': session.refreshToken,
      'phone': session.phone,
    });
    _cache.value = session;
    return session;
  }

  @override
  Future<void> signOut() async {
    final session = current;
    if (session == null) return;
    try {
      await api(session).post('/auth/logout');
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
    final json = await api(session).get('/server/ip');
    return json['ip'] as String;
  }
}

/// Signs requests with the session's latest access token.
class _SessionAuth implements ServerAuth {
  _SessionAuth(this._repo, this._session);

  final ServerRepositoryImpl _repo;
  final ServerSession _session;

  @override
  String get accessToken {
    final now = _repo.current;
    return now != null && now.url == _session.url && now.phone == _session.phone ? now.token : _session.token;
  }

  @override
  Future<String?> renew(String rejected) => _repo._renew(_session, rejected);
}
