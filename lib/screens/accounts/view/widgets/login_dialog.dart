import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../common/di/injector.dart';
import '../../../../common/domain/entities/broker_account.dart';
import '../../viewmodel/login_viewmodel.dart';

/// Daily login: open the broker's login page, then paste back the redirect
/// URL (or the request token / auth code), or paste an access token directly.
/// Groww has no redirect: the user approves access on its API keys page, then
/// generates the session (optionally with a TOTP code).
class LoginDialog extends StatelessWidget {
  const LoginDialog({super.key, required this.account});

  final BrokerAccount account;

  static Future<void> show(BuildContext context, BrokerAccount account) =>
      showDialog<void>(context: context, builder: (_) => LoginDialog(account: account));

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => LoginViewModel(account, sl(), sl(), sl()),
        child: const _LoginBody(),
      );
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<bool> Function(String) action) async {
    final ok = await action(_input.text);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final state = vm.state;
    final redirect = state.redirectLogin;
    return AlertDialog(
      title: Text('Log in — ${vm.account.label}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(redirect
                ? '1. Open the broker login page and sign in.'
                : '1. Open the Groww API keys page and approve today\'s access for this API key.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(Uri.parse(state.loginUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(redirect ? 'Open login page' : 'Open API keys page'),
                ),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: state.loginUrl)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(redirect
                ? '2. Paste the URL you were redirected to (or just the ${state.codeName}).'
                : '2. Tap Generate session. If you use TOTP instead of approval, enter the 6-digit code first.'),
            const SizedBox(height: 8),
            TextField(
              controller: _input,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: redirect ? 'https://…?…' : '${state.codeName} (optional)',
              ),
              maxLines: 3,
              minLines: 1,
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.busy ? null : () => _submit(vm.useAccessToken),
          child: const Text('It is an access token'),
        ),
        FilledButton(
          onPressed: state.busy ? null : () => _submit(vm.loginWithRedirect),
          child: state.busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Generate session'),
        ),
      ],
    );
  }
}
