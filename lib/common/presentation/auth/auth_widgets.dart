import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code_boxes.dart';
import 'login_style.dart';

/// Bold teal text that acts as a button; greyed out when [onTap] is null.
class AuthLink extends StatelessWidget {
  const AuthLink(this.text, {super.key, required this.style, required this.onTap});

  final String text;
  final LoginStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            text,
            style: style.linkText.copyWith(color: onTap == null ? style.muted.withValues(alpha: 0.6) : null),
          ),
        ),
      );
}

/// The full-width teal button; a spinner and disabled while [busy].
class AuthButton extends StatelessWidget {
  const AuthButton(this.label, {super.key, required this.style, required this.busy, required this.onPressed});

  final String label;
  final LoginStyle style;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        style: style.primaryButton,
        child: busy
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: style.onButton),
              )
            : Text(label),
      );
}

/// The error under a step, with the space above it; nothing when [error] is null.
List<Widget> authError(String? error, LoginStyle style) => [
      if (error != null) ...[
        const SizedBox(height: 14),
        Text(error, style: style.errorText),
      ],
    ];

/// `+91` in its own box, then the 10-digit number.
class MobileNumberField extends StatelessWidget {
  const MobileNumberField({
    super.key,
    required this.controller,
    required this.style,
    required this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final LoginStyle style;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: style.box(),
            child: Text('+91', style: style.input),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              key: const Key('mobile'),
              controller: controller,
              style: style.input,
              cursorColor: style.focusedBorder,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              textInputAction: textInputAction,
              onFieldSubmitted: onSubmitted,
              decoration: style.fieldDecoration(hint: '10-digit number'),
              validator: validator,
            ),
          ),
        ],
      );
}

/// The step after a code is texted: six boxes, a resend countdown and Verify.
/// Shared by sign-in and sign-up.
class CodeStep extends StatelessWidget {
  const CodeStep({
    super.key,
    required this.style,
    required this.controller,
    required this.sentTo,
    required this.busy,
    required this.resendIn,
    required this.error,
    required this.onBack,
    required this.onResend,
    required this.onVerify,
    this.errorAction,
  });

  final LoginStyle style;
  final TextEditingController controller;

  /// The number the code went to, e.g. `+91 98765 43210`.
  final String sentTo;
  final bool busy;

  /// Seconds until another code can be requested.
  final int resendIn;
  final String? error;

  /// Back to the step before, e.g. to fix the number.
  final VoidCallback onBack;
  final VoidCallback onResend;
  final VoidCallback onVerify;

  /// Shown under [error], e.g. a link to sign in instead.
  final Widget? errorAction;

  /// `28` → `0:28`.
  static String clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AuthLink('← Back', style: style, onTap: busy ? null : onBack),
          ),
          const SizedBox(height: 28),
          Text('Enter the code', style: style.title),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: style.body,
              children: [
                TextSpan(text: 'We sent a 6-digit code to $sentTo. '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: AuthLink('Change number', style: style, onTap: busy ? null : onBack),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CodeBoxes(
            fieldKey: const Key('code'),
            controller: controller,
            style: style,
            // A full code is checked straight away, e.g. when iOS fills it in from the SMS.
            onChanged: (v) {
              if (v.length == 6) onVerify();
            },
            onSubmitted: (_) => onVerify(),
          ),
          ...authError(error, style),
          if (error != null && errorAction != null)
            Align(alignment: Alignment.centerLeft, child: errorAction),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  resendIn > 0 ? 'Resend code in ${clock(resendIn)}' : 'Didn\'t get it?',
                  style: style.label,
                ),
              ),
              AuthLink('Resend', style: style, onTap: busy || resendIn > 0 ? null : onResend),
            ],
          ),
          const SizedBox(height: 24),
          AuthButton('Verify and continue', style: style, busy: busy, onPressed: onVerify),
        ],
      );
}
