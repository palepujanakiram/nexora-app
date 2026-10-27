import 'dart:async';

import 'package:nexora_app/common/domain/entities/proxy_health.dart';
import 'package:nexora_app/common/domain/repositories/proxy_repository.dart';

/// Records checked URLs; answers with [health], or waits on [gate] if set.
class FakeProxyRepository implements ProxyRepository {
  FakeProxyRepository({this.health = const ProxyHealth(ProxyHealthStatus.connected), this.script = 'worker()'});

  ProxyHealth health;
  String script;
  Completer<void>? gate;
  final checked = <String>[];

  @override
  Future<String> workerScript() async => script;

  @override
  Future<ProxyHealth> check(String proxyUrl) async {
    checked.add(proxyUrl);
    await gate?.future;
    return health;
  }
}
