/// What someone fills in to create their own account, besides the mobile
/// number. The server records each confirmation with the date and time.
class SignUpDetails {
  const SignUpDetails({
    required this.fullName,
    required this.email,
    this.acceptsTerms = false,
    this.acceptsRisk = false,
    this.acceptsDataUse = false,
  });

  /// As on the user's PAN.
  final String fullName;
  final String email;

  /// The Terms of Use and the Privacy Notice.
  final bool acceptsTerms;

  /// That signals are research views and derivatives can lose money.
  final bool acceptsRisk;

  /// How the user's data is used for the service.
  final bool acceptsDataUse;

  /// The server creates the account only when every statement is confirmed.
  bool get confirmedAll => acceptsTerms && acceptsRisk && acceptsDataUse;
}
