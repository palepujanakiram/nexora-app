import 'package:flutter/material.dart';

/// The sign-in and sign-up screens' own look: a mint page, white fields and a teal button,
/// with darker equivalents in dark mode. Text uses the system font: San
/// Francisco on iOS, Roboto on Android.
class LoginStyle {
  const LoginStyle._({
    required this.page,
    required this.field,
    required this.border,
    required this.focusedBorder,
    required this.text,
    required this.muted,
    required this.link,
    required this.button,
    required this.onButton,
    required this.error,
  });

  factory LoginStyle.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = LoginStyle._(
    page: Color(0xFFEEF6F4),
    field: Colors.white,
    border: Color(0xFFCFE0DB),
    focusedBorder: Color(0xFF0F766E),
    text: Color(0xFF0B1215),
    muted: Color(0xFF4F625D),
    link: Color(0xFF0F766E),
    button: Color(0xFF2DD4BF),
    onButton: Color(0xFF0B1215),
    error: Color(0xFFB42318),
  );

  static const _dark = LoginStyle._(
    page: Color(0xFF0E1A18),
    field: Color(0xFF152623),
    border: Color(0xFF2B4540),
    focusedBorder: Color(0xFF2DD4BF),
    text: Color(0xFFE6F2EF),
    muted: Color(0xFF9DB5AF),
    link: Color(0xFF5EEAD4),
    button: Color(0xFF2DD4BF),
    onButton: Color(0xFF0B1215),
    error: Color(0xFFFF8A80),
  );

  final Color page;
  final Color field;
  final Color border;
  final Color focusedBorder;
  final Color text;
  final Color muted;
  final Color link;
  final Color button;
  final Color onButton;
  final Color error;

  static const radius = BorderRadius.all(Radius.circular(12));

  TextStyle get _base => const TextStyle();

  /// The letter-spaced wordmark above the title.
  TextStyle get brand => _base.copyWith(fontSize: 44, fontWeight: FontWeight.w400, letterSpacing: 3, height: 1.4, color: text);
  TextStyle get title => _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, color: text);
  TextStyle get body => _base.copyWith(fontSize: 15, height: 1.6, color: muted);
  TextStyle get label => _base.copyWith(fontSize: 14, color: muted);
  TextStyle get input => _base.copyWith(fontSize: 17, color: text);
  TextStyle get hint => _base.copyWith(fontSize: 17, color: muted.withValues(alpha: 0.7));
  TextStyle get linkText => _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: link);
  TextStyle get buttonText => _base.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: onButton);
  TextStyle get errorText => _base.copyWith(fontSize: 14, height: 1.4, color: error);

  /// A white rounded box, highlighted when [focused].
  BoxDecoration box({bool focused = false, bool hasError = false}) => BoxDecoration(
        color: field,
        borderRadius: radius,
        border: Border.all(
          color: hasError ? error : (focused ? focusedBorder : border),
          width: focused || hasError ? 2 : 1.5,
        ),
      );

  InputDecoration fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: this.hint,
        filled: true,
        fillColor: field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        errorStyle: errorText,
        errorMaxLines: 2,
        enabledBorder: _outline(border, 1.5),
        focusedBorder: _outline(focusedBorder, 2),
        errorBorder: _outline(error, 1.5),
        focusedErrorBorder: _outline(error, 2),
      );

  OutlineInputBorder _outline(Color color, double width) =>
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: color, width: width));

  ButtonStyle get primaryButton => FilledButton.styleFrom(
        backgroundColor: button,
        foregroundColor: onButton,
        disabledBackgroundColor: button.withValues(alpha: 0.5),
        disabledForegroundColor: onButton.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(60),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      );
}
