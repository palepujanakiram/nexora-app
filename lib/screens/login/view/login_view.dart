import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/server_session.dart';
import '../../../common/presentation/auth/auth_widgets.dart';
import '../../../common/presentation/auth/login_style.dart';
import '../../signup/view/sign_up_view.dart';
import '../model/login_state.dart';
import '../usecase/send_code_usecase.dart';
import '../viewmodel/login_viewmodel.dart';

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

  /// Opens sign-up on the same server. It comes back with the number when
  /// that number already has an account, ready to sign in.
  Future<void> _createAccount() async {
    final mobile = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => SignUpView(url: _url.text)),
    );
    if (mobile != null && mobile.isNotEmpty) _mobile.text = mobile;
  }

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
                  children: state.enteringCode ? [_codeStep(vm, state, style)] : _phoneStep(vm, state, style),
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
              MobileNumberField(
                controller: _mobile,
                style: style,
                onSubmitted: (_) => _sendCode(vm),
                validator: _validateMobile,
              ),
              ...authError(state.error, style),
              const SizedBox(height: 24),
              AuthButton('Send code', style: style, busy: state.busy, onPressed: () => _sendCode(vm)),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('New to Srisarani Stocks? ', style: style.body),
                  AuthLink('Create an account', style: style, onTap: state.busy ? null : _createAccount),
                ],
              ),
              const SizedBox(height: 16),
              _serverTile(style),
            ],
          ),
        ),
      ];

  Widget _codeStep(LoginViewModel vm, LoginState state, LoginStyle style) => CodeStep(
        style: style,
        controller: _code,
        sentTo: state.sentTo!,
        busy: state.busy,
        resendIn: state.resendIn,
        error: state.error,
        onBack: vm.changeNumber,
        onResend: () => _resend(vm),
        onVerify: () => _verify(vm),
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
