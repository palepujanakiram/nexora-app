import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/entities/server_session.dart';

class GuideLink {
  const GuideLink(this.label, this.url);
  final String label;
  final String url;
}

/// Per-broker form labels and "where do I get these keys?" instructions.
class BrokerSetupGuide {
  const BrokerSetupGuide({
    required this.broker,
    required this.title,
    required this.subtitle,
    required this.apiKeyLabel,
    required this.apiSecretLabel,
    required this.needsRedirectUri,
    required this.steps,
    required this.links,
    this.redirectUriHelp,
  });

  final BrokerType broker;
  final String title;
  final String subtitle;
  final String apiKeyLabel;
  final String apiSecretLabel;
  final bool needsRedirectUri;
  final String? redirectUriHelp;
  final List<String> steps;
  final List<GuideLink> links;

  static BrokerSetupGuide of(BrokerType broker) => switch (broker) {
        BrokerType.zerodha => zerodha,
        BrokerType.upstox => upstox,
        BrokerType.groww => groww,
      };

  static const zerodha = BrokerSetupGuide(
    broker: BrokerType.zerodha,
    title: 'Zerodha',
    subtitle: 'Kite Connect API',
    apiKeyLabel: 'API key',
    apiSecretLabel: 'API secret',
    needsRedirectUri: false,
    steps: [
      'Sign in to the Kite Connect developer console with your Zerodha account.',
      'Create a new app. Enter your Zerodha client ID, and set the redirect URL to your server\'s address followed by '
          '/broker-callback/zerodha, e.g. ${ServerSession.defaultUrl}/broker-callback/zerodha.',
      'Open the app and copy its API key and API secret into the fields above.',
      'Check Kite Connect pricing and any static IP requirement for order placement on the developer site.',
    ],
    links: [
      GuideLink('Kite Connect developer console', 'https://developers.kite.trade/'),
      GuideLink('Kite Connect login flow docs', 'https://kite.trade/docs/connect/v3/user/'),
    ],
  );

  static const upstox = BrokerSetupGuide(
    broker: BrokerType.upstox,
    title: 'Upstox',
    subtitle: 'Upstox Developer API',
    apiKeyLabel: 'API key (client_id)',
    apiSecretLabel: 'API secret',
    needsRedirectUri: true,
    redirectUriHelp: 'Must exactly match the redirect URL saved in your Upstox app',
    steps: [
      'Sign in to Upstox and open My Account → Apps (developer apps page).',
      'Create a new app. Set its redirect URL to the address in the Redirect URI field above: your server\'s '
          'address followed by /broker-callback/upstox, e.g. ${ServerSession.defaultUrl}/broker-callback/upstox.',
      'Copy the API key and API secret into the fields above. The redirect URL must match exactly, or Upstox '
          'refuses the login ("Check your client_id and redirect_uri").',
      'Check whether Upstox requires a static IP for placing orders through the API.',
    ],
    links: [
      GuideLink('Upstox developer apps', 'https://account.upstox.com/developer/apps'),
      GuideLink('Upstox authentication docs', 'https://upstox.com/developer/api-documentation/authentication'),
    ],
  );

  static const groww = BrokerSetupGuide(
    broker: BrokerType.groww,
    title: 'Groww',
    subtitle: 'Groww Trade API',
    apiKeyLabel: 'API key',
    apiSecretLabel: 'API secret',
    needsRedirectUri: false,
    steps: [
      'Subscribe to Groww Trading APIs in the Groww app or website (Profile → Trading APIs).',
      'Open the Groww API keys page and generate an API key and secret.',
      'Copy the API key and API secret into the fields above.',
      'Each trading day, approve the key on the API keys page, then tap Login → Generate session in NexoraApp.',
      'NexoraApp places the entry order only on Groww; add the stop loss / target (OCO) in the Groww app after it fills.',
    ],
    links: [
      GuideLink('Groww API keys', 'https://groww.in/trade-api/api-keys'),
      GuideLink('Groww Trading APIs subscription', 'https://groww.in/user/profile/trading-apis'),
      GuideLink('Groww Trade API docs', 'https://groww.in/trade-api/docs/curl'),
    ],
  );
}
