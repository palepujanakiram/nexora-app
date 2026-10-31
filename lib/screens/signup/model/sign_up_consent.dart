/// The statements a new user confirms, one checkbox each. The wording is a
/// placeholder until compliance supplies the final text; the server records
/// which version was shown.
enum SignUpConsent {
  terms('I accept the Terms of Use and the Privacy Notice.'),
  risk('I understand that signals are research views, not orders, and that trading in derivatives can lose money.'),
  dataUse('I agree to how my data is used for this service.');

  const SignUpConsent(this.statement);

  final String statement;
}
