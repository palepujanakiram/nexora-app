import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/services/account_rules.dart';
import '../../../common/presentation/auth/auth_widgets.dart';
import '../../../common/presentation/auth/login_style.dart';
import '../model/sign_up_consent.dart';
import '../model/sign_up_state.dart';
import '../viewmodel/sign_up_viewmodel.dart';

/// Creates an account on the nexora-backend server at [url]: name, mobile
/// number, email and the statements to confirm, then the code texted to the
/// number. Opened from the sign-in screen; pops with the mobile number when
/// the user should sign in instead.
class SignUpView extends StatelessWidget {
  const SignUpView({super.key, required this.url});

  /// The server to sign up on, as set on the sign-in screen.
  final String url;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => SignUpViewModel(sl(), sl()),
        child: _SignUpBody(url: url),
      );
}

class _SignUpBody extends StatefulWidget {
  const _SignUpBody({required this.url});

  final String url;

  @override
  State<_SignUpBody> createState() => _SignUpBodyState();
}

class _SignUpBodyState extends State<_SignUpBody> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// After a failed submit, fields re-check as the user fixes them.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode(SignUpViewModel vm) async {
    if (!_form.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final sent = await vm.sendCode(url: widget.url, mobile: _mobile.text, fullName: _name.text, email: _email.text);
    if (sent) _code.clear();
  }

  Future<void> _resend(SignUpViewModel vm) async {
    if (await vm.resend()) _code.clear();
  }

  // Signed in: the app's home replaces the sign-in screen underneath, so close this one.
  Future<void> _verify(SignUpViewModel vm) async {
    if (await vm.verify(_code.text) && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Back to sign-in, with the number when it already has an account.
  void _signIn([String? mobile]) => Navigator.of(context).maybePop(mobile);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignUpViewModel>();
    final state = vm.state;
    final style = LoginStyle.of(context);

    return Scaffold(
      backgroundColor: style.page,
      // Tapping anywhere outside a field, or scrolling, closes the keyboard.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: state.enteringCode
                    ? CodeStep(
                        style: style,
                        controller: _code,
                        sentTo: state.sentTo!,
                        busy: state.busy,
                        resendIn: state.resendIn,
                        error: state.error,
                        onBack: vm.editDetails,
                        onResend: () => _resend(vm),
                        onVerify: () => _verify(vm),
                        errorAction: state.alreadyRegistered
                            ? AuthLink('Sign in instead', style: style, onTap: () => _signIn(_mobile.text))
                            : null,
                      )
                    : _formStep(vm, state, style),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formStep(SignUpViewModel vm, SignUpState state, LoginStyle style) => Form(
        key: _form,
        autovalidateMode: _autovalidate,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AuthLink('← Back', style: style, onTap: state.busy ? null : _signIn),
              ),
              const SizedBox(height: 28),
              Text('Create your account', style: style.title),
              const SizedBox(height: 12),
              Text('It takes about a minute.', style: style.body),
              const SizedBox(height: 28),
              Text('Full name', style: style.label),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('fullName'),
                controller: _name,
                style: style.input,
                cursorColor: style.focusedBorder,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: style.fieldDecoration(hint: 'As on your PAN'),
                validator: (v) => AccountRules.fullNameProblem(v ?? ''),
              ),
              const SizedBox(height: 20),
              Text('Mobile number', style: style.label),
              const SizedBox(height: 10),
              MobileNumberField(
                controller: _mobile,
                style: style,
                textInputAction: TextInputAction.next,
                validator: (v) => AccountRules.mobileProblem(v ?? ''),
              ),
              const SizedBox(height: 20),
              Text('Email', style: style.label),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('email'),
                controller: _email,
                style: style.input,
                cursorColor: style.focusedBorder,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                decoration: style.fieldDecoration(hint: 'you@example.com'),
                validator: (v) => AccountRules.emailProblem(v ?? ''),
              ),
              const SizedBox(height: 28),
              Text('PLEASE CONFIRM EACH OF THESE', style: style.label.copyWith(fontSize: 13, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              for (final consent in SignUpConsent.values)
                _consentRow(consent, state.confirmed.contains(consent), state.busy ? null : vm.confirm, style),
              ...authError(state.error, style),
              const SizedBox(height: 28),
              AuthButton('Create account and send code', style: style, busy: state.busy, onPressed: () => _sendCode(vm)),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Already have an account? ', style: style.body),
                  AuthLink('Sign in', style: style, onTap: state.busy ? null : _signIn),
                ],
              ),
            ],
          ),
        ),
      );

  /// A checkbox with its statement; tapping the text ticks it too.
  Widget _consentRow(
    SignUpConsent consent,
    bool ticked,
    void Function(SignUpConsent, bool)? onChanged,
    LoginStyle style,
  ) =>
      InkWell(
        key: Key('consent-${consent.name}'),
        onTap: onChanged == null ? null : () => onChanged(consent, !ticked),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: ticked,
                activeColor: style.focusedBorder,
                side: BorderSide(color: style.muted, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: onChanged == null ? null : (v) => onChanged(consent, v ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(consent.statement, style: style.input.copyWith(fontSize: 15, height: 1.45)),
                ),
              ),
            ],
          ),
        ),
      );
}
