import '../../../common/domain/entities/proxy_health.dart';
import '../../../common/domain/repositories/proxy_repository.dart';

/// Checks that the proxy URL answers and accepts this app's origin.
class TestProxyUseCase {
  const TestProxyUseCase(this._proxy);

  final ProxyRepository _proxy;

  Future<ProxyHealth> call(String proxyUrl) => _proxy.check(proxyUrl);
}
