import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/server_session.dart';
import '../../../common/presentation/widgets/info_banner.dart';
import '../model/login_state.dart';
import '../usecase/send_code_usecase.dart';
import '../viewmodel/login_viewmodel.dart';

/// The first screen: everything else needs a signed-in nexora-backend server.
/// Sign-in is a mobile number, then the one-time code texted to it.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

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
  final _invite = TextEditingController();
  final _code = TextEditingController();
  final _url = TextEditingController(text: ServerSession.defaultUrl);

  /// After a failed Send, fields re-check as the user fixes them, so a stale
  /// error doesn't stay on a corrected number.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final c in [_mobile, _invite, _code, _url]) {
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
    if (await vm.sendCode(url: _url.text, mobile: _mobile.text, inviteCode: _invite.text)) _code.clear();
  }

  Future<void> _resend(LoginViewModel vm) async {
    if (await vm.resend()) _code.clear();
  }

  // On success the app swaps this screen for home; nothing to do here.
  Future<void> _verify(LoginViewModel vm) => vm.verify(_code.text);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final state = vm.state;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.candlestick_chart, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Srisarani Stocks', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    state.enteringCode ? 'Enter the code' : 'Sign in with your mobile number',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (state.notice != null && !state.enteringCode) ...[
                    InfoBanner(text: state.notice!, color: theme.colorScheme.secondaryContainer),
                    const SizedBox(height: 16),
                  ],
                  ...state.enteringCode ? _codeStep(vm, state, theme) : _phoneStep(vm, state, theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(LoginViewModel vm, LoginState state, ThemeData theme) => [
        Form(
          key: _phoneForm,
          autovalidateMode: _autovalidate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('mobile'),
                controller: _mobile,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _sendCode(vm),
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(),
                  helperText: 'We\'ll text you a code to sign in.',
                ),
                validator: _validateMobile,
              ),
              if (state.needsInvite) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('invite'),
                  controller: _invite,
                  autofocus: true,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendCode(vm),
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    border: OutlineInputBorder(),
                    helperText: 'Only for your first sign-in. Ask whoever runs the server.',
                    helperMaxLines: 2,
                  ),
                  validator: _required,
                ),
              ],
              ..._error(state, theme),
              const SizedBox(height: 20),
              _primaryButton(state, label: 'Send code', onPressed: () => _sendCode(vm)),
              const SizedBox(height: 8),
              _serverTile(theme),
            ],
          ),
        ),
      ];

  List<Widget> _codeStep(LoginViewModel vm, LoginState state, ThemeData theme) => [
        Text('We sent a 6-digit code to ${state.sentTo}.', textAlign: TextAlign.center),
        TextButton(
          onPressed: state.busy ? null : vm.changeNumber,
          child: const Text('Change number'),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('code'),
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
          decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder()),
          // A full code is checked straight away, e.g. when iOS fills it in from the SMS.
          onChanged: (v) {
            if (v.length == 6) _verify(vm);
          },
          onSubmitted: (_) => _verify(vm),
        ),
        ..._error(state, theme),
        const SizedBox(height: 20),
        _primaryButton(state, label: 'Verify and sign in', onPressed: () => _verify(vm)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.busy || state.resendIn > 0 ? null : () => _resend(vm),
          child: Text(state.resendIn > 0 ? 'Resend code in ${state.resendIn}s' : 'Resend code'),
        ),
      ];

  List<Widget> _error(LoginState state, ThemeData theme) => [
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ];

  Widget _primaryButton(LoginState state, {required String label, required VoidCallback onPressed}) => FilledButton(
        onPressed: state.busy ? null : onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: state.busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      );

  Widget _serverTile(ThemeData theme) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text('Server', style: theme.textTheme.titleSmall),
        subtitle: ValueListenableBuilder(
          valueListenable: _url,
          builder: (_, value, _) => Text(value.text.trim(), overflow: TextOverflow.ellipsis),
        ),
        children: [
          TextFormField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Server address',
              border: const OutlineInputBorder(),
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
      );
}
