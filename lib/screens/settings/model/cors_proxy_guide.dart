class ProxyGuideLink {
  const ProxyGuideLink(this.label, this.url);
  final String label;
  final String url;
}

/// Steps for creating the Cloudflare Worker proxy from the dashboard,
/// no command line needed.
abstract final class CorsProxyGuide {
  static const steps = [
    'Create a free Cloudflare account, then open Workers & Pages.',
    'Create a Worker from the "Hello World" starter, name it e.g. nexora-cors-proxy, and deploy it.',
    'Click "Edit code", delete the sample code, paste the NexoraApp proxy code (Copy proxy code below), and deploy again.',
    'Copy the Worker URL (https://nexora-cors-proxy.<your-subdomain>.workers.dev), paste it into the field above, and tap Test proxy.',
  ];

  static const defaultsNote =
      'Out of the box the proxy only accepts the app running on localhost and blocks placing orders, '
      'so it is safe for paper trading. If you host the web app on another address, add a variable '
      'ALLOWED_ORIGINS in the Worker\'s Settings → Variables, e.g. http://localhost:*,https://your-app.example.com';

  static const cliNote = 'Prefer the command line? See proxy/cloudflare-worker/README.md in the project (npx wrangler deploy).';

  static const links = [
    ProxyGuideLink('Create a Cloudflare account', 'https://dash.cloudflare.com/sign-up'),
    ProxyGuideLink('Workers & Pages dashboard', 'https://dash.cloudflare.com/?to=/:account/workers-and-pages'),
    ProxyGuideLink('Cloudflare guide: create a Worker in the dashboard',
        'https://developers.cloudflare.com/workers/get-started/dashboard/'),
    ProxyGuideLink('Cloudflare guide: Worker variables',
        'https://developers.cloudflare.com/workers/configuration/environment-variables/'),
  ];
}
