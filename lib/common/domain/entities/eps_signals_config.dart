/// Where the EMA Pivot signals Feed tab gets its data: a deployed
/// proxy/cloudflare-worker `/signals` route that holds the vendor's API key
/// server-side (see proxy/cloudflare-worker/README.md). There's one correct
/// value for this app's own deployment, so — like [ServerSession.defaultUrl]
/// — it's a build-time default rather than a per-user setting.
/// Override with `--dart-define=EPS_SIGNALS_PROXY_URL=https://…`.
abstract final class EpsSignalsConfig {
  static const proxyUrl = String.fromEnvironment('EPS_SIGNALS_PROXY_URL');

  static const isConfigured = proxyUrl != '';
}
