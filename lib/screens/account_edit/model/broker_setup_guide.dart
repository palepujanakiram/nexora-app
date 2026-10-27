import '../../../common/domain/entities/broker_account.dart';

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
      'Create a new app. Enter your Zerodha client ID and any redirect URL you can open, '
          'e.g. https://127.0.0.1/ — after logging in you will paste the page address back into NexoraApp.',
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
      'Create a new app. Set a redirect URL you can open, e.g. https://127.0.0.1/ — '
          'after logging in you will paste the page address back into NexoraApp.',
      'Copy the API key and API secret into the fields above, and enter the same redirect URL exactly.',
      'Check whether Upstox requires a static IP for placing orders through the API.',
    ],
    links: [
      GuideLink('Upstox developer apps', 'https://account.upstox.com/developer/apps'),
      GuideLink('Upstox authentication docs', 'https://upstox.com/developer/api-documentation/authentication'),
    ],
  );
}
