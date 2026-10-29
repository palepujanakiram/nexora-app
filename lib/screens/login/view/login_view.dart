import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/server_session.dart';
import '../model/login_state.dart';
import '../usecase/send_code_usecase.dart';
import '../viewmodel/login_viewmodel.dart';
import 'widgets/code_boxes.dart';
import 'widgets/login_style.dart';

/// The first screen: everything else needs a signed-in nexora-backend server.
/// Sign-in is a mobile number, then the one-time code texted to it.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  /// The wordmark at the top of the number screen.
  static const brand = 'SRISARANI\nSTOCKS';

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => LoginViewModel(sl(), sl(), sl()),
        child: const _LoginBody(),
      );
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _phoneForm = GlobalKey<FormState>();
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  final _url = TextEditingController(text: ServerSession.defaultUrl);

  /// After a failed Send, fields re-check as the user fixes them, so a stale
  /// error doesn't stay on a corrected number.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final c in [_mobile, _code, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _validateMobile(String? v) => SendCodeUseCase.problemWith(v ?? '');

  static String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _sendCode(LoginViewModel vm) async {
    if (!_phoneForm.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    if (await vm.sendCode(url: _url.text, mobile: _mobile.text)) _code.clear();
  }

  Future<void> _resend(LoginViewModel vm) async {
    if (await vm.resend()) _code.clear();
  }

  // On success the app swaps this screen for home; nothing to do here.
  Future<void> _verify(LoginViewModel vm) => vm.verify(_code.text);

  /// `28` → `0:28`.
  static String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: state.enteringCode ? _codeStep(vm, state, style) : _phoneStep(vm, state, style),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(LoginViewModel vm, LoginState state, LoginStyle style) => [
        // Two lines, SRISARANI over STOCKS; shrinks on narrow screens rather than wrapping further.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(LoginView.brand, style: style.brand, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 40),
        Text('Welcome back', style: style.title),
        const SizedBox(height: 16),
        Text('Sign in with your mobile number. We will send you a one-time code.', style: style.body),
        if (state.notice != null) ...[
          const SizedBox(height: 16),
          Text(state.notice!, style: style.body.copyWith(color: style.link, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 32),
        Form(
          key: _phoneForm,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mobile number', style: style.label),
              const SizedBox(height: 10),
              Row(
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
                      controller: _mobile,
                      style: style.input,
                      cursorColor: style.focusedBorder,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _sendCode(vm),
                      decoration: style.fieldDecoration(hint: '10-digit number'),
                      validator: _validateMobile,
                    ),
                  ),
                ],
              ),
              ..._error(state, style),
              const SizedBox(height: 24),
              _primaryButton(state, style, label: 'Send code', onPressed: () => _sendCode(vm)),
              const SizedBox(height: 24),
              _serverTile(style),
            ],
          ),
        ),
      ];

  List<Widget> _codeStep(LoginViewModel vm, LoginState state, LoginStyle style) => [
        Align(
          alignment: Alignment.centerLeft,
          child: _link(style, '← Back', state.busy ? null : vm.changeNumber),
        ),
        const SizedBox(height: 28),
        Text('Enter the code', style: style.title),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            style: style.body,
            children: [
              TextSpan(text: 'We sent a 6-digit code to ${state.sentTo}. '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _link(style, 'Change number', state.busy ? null : vm.changeNumber),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        CodeBoxes(
          fieldKey: const Key('code'),
          controller: _code,
          style: style,
          // A full code is checked straight away, e.g. when iOS fills it in from the SMS.
          onChanged: (v) {
            if (v.length == 6) _verify(vm);
          },
          onSubmitted: (_) => _verify(vm),
        ),
        ..._error(state, style),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                state.resendIn > 0 ? 'Resend code in ${_clock(state.resendIn)}' : 'Didn\'t get it?',
                style: style.label,
              ),
            ),
            _link(style, 'Resend', state.busy || state.resendIn > 0 ? null : () => _resend(vm)),
          ],
        ),
        const SizedBox(height: 24),
        _primaryButton(state, style, label: 'Verify and continue', onPressed: () => _verify(vm)),
      ];

  /// Bold teal text that acts as a button; greyed out when [onTap] is null.
  Widget _link(LoginStyle style, String text, VoidCallback? onTap) => InkWell(
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

  List<Widget> _error(LoginState state, LoginStyle style) => [
        if (state.error != null) ...[
          const SizedBox(height: 14),
          Text(state.error!, style: style.errorText),
        ],
      ];

  Widget _primaryButton(LoginState state, LoginStyle style, {required String label, required VoidCallback onPressed}) =>
      FilledButton(
        onPressed: state.busy ? null : onPressed,
        style: style.primaryButton,
        child: state.busy
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: style.onButton),
              )
            : Text(label),
      );

  /// Where the app signs in. Collapsed: most people never change it.
  Widget _serverTile(LoginStyle style) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          iconColor: style.muted,
          collapsedIconColor: style.muted,
          title: Text('Server', style: style.label),
          subtitle: ValueListenableBuilder(
            valueListenable: _url,
            builder: (_, value, _) => Text(
              value.text.trim(),
              overflow: TextOverflow.ellipsis,
              style: style.label.copyWith(fontSize: 12),
            ),
          ),
          children: [
            TextFormField(
              controller: _url,
              style: style.input.copyWith(fontSize: 15),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: style.fieldDecoration().copyWith(
                    labelText: 'Server address',
                    helperText: 'Change only if you run your own nexora-backend.',
                    suffixIcon: IconButton(
                      tooltip: 'Use the default server',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: () => _url.text = ServerSession.defaultUrl,
                    ),
                  ),
              validator: _required,
            ),
          ],
        ),
      );
}
