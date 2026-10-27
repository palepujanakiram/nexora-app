import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/proxy_health.dart';
import '../../domain/repositories/proxy_repository.dart';

class ProxyRepositoryImpl implements ProxyRepository {
  ProxyRepositoryImpl(this._http, [AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  /// Bundled from the repo so the app always ships the matching worker.
  static const workerAsset = 'proxy/cloudflare-worker/src/index.js';
  static const _timeout = Duration(seconds: 10);

  final http.Client _http;
  final AssetBundle _bundle;

  @override
  Future<String> workerScript() => _bundle.loadString(workerAsset);

  @override
  Future<ProxyHealth> check(String proxyUrl) async {
    final base = proxyUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base/health');
    if (base.isEmpty || uri == null || !uri.hasScheme) return const ProxyHealth(ProxyHealthStatus.unreachable);

    final http.Response res;
    try {
      res = await _http.get(uri).timeout(_timeout);
    } catch (_) {
      return const ProxyHealth(ProxyHealthStatus.unreachable);
    }

    final Object? body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      return const ProxyHealth(ProxyHealthStatus.notAProxy);
    }
    if (body is! Map || body['service'] != 'nexora-cors-proxy') {
      return const ProxyHealth(ProxyHealthStatus.notAProxy);
    }
    return ProxyHealth(
      body['originAllowed'] == true ? ProxyHealthStatus.connected : ProxyHealthStatus.originNotAllowed,
      origin: body['origin'] as String?,
      ordersEnabled: body['ordersEnabled'] == true,
    );
  }
}
