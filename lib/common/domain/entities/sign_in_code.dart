/// A one-time sign-in code the server has texted to [phone].
class SignInCode {
  const SignInCode({required this.phone, required this.expiresIn, required this.resendIn});

  /// The number in E.164 (`+919876543210`), to send back with the code.
  final String phone;

  /// How long the code works.
  final Duration expiresIn;

  /// How long until another code can be requested.
  final Duration resendIn;
}
