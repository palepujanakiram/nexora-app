/// Where users write to withdraw consent. Set at build time with
/// `--dart-define=SUPPORT_EMAIL=…`; until then the text names the support team.
const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

/// [supportEmail], or `our support team` when the build doesn't set one.
const supportContact = supportEmail == '' ? 'our support team' : supportEmail;

/// The statements a new user confirms, one checkbox each. The server records
/// which version of the wording was shown (its `CONSENT_VERSION`), so bump that
/// whenever this text changes.
enum SignUpConsent {
  terms('I have read and accept the Terms of Use and the Privacy Notice.'),
  risk('I understand that signals are research views, not personal advice or a promise of returns. '
      'Trading in futures and options is high risk, and SEBI studies show most individual traders lose money. '
      'Orders I approve are placed on my own broker accounts, and the decisions and any losses are mine.'),
  dataUse('I agree that Srisarani Stocks may use my name, mobile number and email, and keep my broker '
      'connections, to run my account, send me sign-in codes and service messages, place the orders I approve, '
      'and keep records required by law. I can withdraw this consent at any time by writing to $supportContact.');

  const SignUpConsent(this.statement);

  final String statement;
}
