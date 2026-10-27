import '../entities/proxy_health.dart';

/// The web CORS proxy: its deployable source and a connectivity check.
abstract interface class ProxyRepository {
  /// Cloudflare Worker source the user can paste into the Cloudflare dashboard.
  Future<String> workerScript();

  Future<ProxyHealth> check(String proxyUrl);
}
