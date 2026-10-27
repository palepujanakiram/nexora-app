enum ProxyHealthStatus {
  /// Reachable and this app's origin is allowed.
  connected,

  /// Reachable, but the worker rejects this app's origin.
  originNotAllowed,

  /// Something answered, but it isn't a NexoraApp proxy.
  notAProxy,

  /// No response (wrong URL, not deployed, offline, or blocked by CORS).
  unreachable,
}

class ProxyHealth {
  const ProxyHealth(this.status, {this.origin, this.ordersEnabled = false});

  final ProxyHealthStatus status;

  /// The web origin the proxy saw, e.g. `http://localhost:52341`.
  final String? origin;
  final bool ordersEnabled;
}
