import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/server_session.dart';
import '../../../common/presentation/widgets/info_banner.dart';
import '../viewmodel/login_viewmodel.dart';

/// The first screen: everything else needs a signed-in nexora-backend server.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => LoginViewModel(sl(), sl()),
        child: const _LoginBody(),
      );
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  final _url = TextEditingController(text: ServerSession.defaultUrl);
  bool _showPassword = false;

  @override
  void dispose() {
    for (final c in [_email, _password, _invite, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _validatePassword(String? v, bool creating) {
    if (v == null || v.isEmpty) return 'Required';
    if (creating && v.length < 10) return 'Use at least 10 characters.';
    return null;
  }

  Future<void> _submit(LoginViewModel vm) async {
    if (!_form.currentState!.validate()) return;
    // On success the app swaps this screen for home; nothing to do here.
    await vm.submit(url: _url.text, email: _email.text, password: _password.text, inviteCode: _invite.text);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final state = vm.state;
    final theme = Theme.of(context);
    final creating = state.creating;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.candlestick_chart, size: 56, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('NexoraApp', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        creating ? 'Create your login' : 'Sign in to your server',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      if (state.notice != null) ...[
                        InfoBanner(text: state.notice!, color: theme.colorScheme.secondaryContainer),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: [creating ? AutofillHints.newPassword : AutofillHints.password],
                        textInputAction: creating ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: creating ? null : (_) => _submit(vm),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          helperText: creating ? 'At least 10 characters.' : null,
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Hide password' : 'Show password',
                            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (v) => _validatePassword(v, creating),
                      ),
                      if (creating) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _invite,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(vm),
                          decoration: const InputDecoration(
                            labelText: 'Invite code',
                            border: OutlineInputBorder(),
                            helperText: 'Ask whoever runs the server.',
                          ),
                          validator: _required,
                        ),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: state.busy ? null : () => _submit(vm),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: state.busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(creating ? 'Create login' : 'Sign in'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: state.busy ? null : () => vm.setCreating(!creating),
                        child: Text(creating ? 'Have a login? Sign in' : 'New here? Create a login'),
                      ),
                      const SizedBox(height: 8),
                      ExpansionTile(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
