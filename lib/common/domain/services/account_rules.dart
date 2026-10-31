/// The checks the server applies to a mobile number, name and email, so the
/// app can explain a problem before sending anything.
abstract final class AccountRules {
  /// Why [mobile] isn't an Indian mobile number, or null when it is.
  static String? mobileProblem(String mobile) {
    final digits = _digits(mobile);
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) return 'Enter your 10-digit mobile number.';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Indian mobile numbers start with 6, 7, 8 or 9.';
    return null;
  }

  /// `98765 43210` → `+919876543210`.
  static String e164(String mobile) => '+91${_digits(mobile)}';

  static String _digits(String mobile) => mobile.replaceAll(RegExp(r'[\s-]'), '');

  /// Why [name] isn't a full name, or null. Letters, spaces, dots, apostrophes
  /// and hyphens, starting with a letter: the same rule as the server.
  static String? fullNameProblem(String name) {
    final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final ok = RegExp(r"^\p{L}[\p{L}\p{M} .'-]{1,99}$", unicode: true).hasMatch(collapsed);
    return ok ? null : 'Enter your full name.';
  }

  /// Why [email] isn't an email address, or null.
  static String? emailProblem(String email) {
    final trimmed = email.trim();
    final ok = trimmed.length <= 200 && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
    return ok ? null : 'Enter a valid email address.';
  }
}
