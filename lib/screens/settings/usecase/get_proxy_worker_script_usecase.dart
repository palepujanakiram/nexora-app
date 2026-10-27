import '../../../common/domain/repositories/proxy_repository.dart';

class GetProxyWorkerScriptUseCase {
  const GetProxyWorkerScriptUseCase(this._proxy);

  final ProxyRepository _proxy;

  Future<String> call() => _proxy.workerScript();
}
