import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../common/di/injector.dart';
import '../../../../common/domain/entities/broker_account.dart';
import '../../model/login_redirect.dart';
import '../../viewmodel/login_viewmodel.dart';
import 'broker_login_page.dart';

/// Daily login. With a server, Zerodha and Upstox redirect to the server,
/// which finishes the login: the broker's page opens in the system browser
/// (Safari's in-app view on iPhone) and the dialog waits until the server
/// reports the account logged in. The app's own web view isn't used there:
/// it keeps retrying Upstox over HTTP/3 once Upstox has advertised it, and
/// hangs where that doesn't get through.
///
/// Without a server, on iOS/Android the broker's page opens in an in-app
/// browser and the redirect is caught automatically. Otherwise (and as a
/// fallback) the user opens the login page in a browser and pastes back the
/// redirect URL, or pastes an access token. Groww has no redirect: the user
/// approves access on its API keys page, then generates the session
/// (optionally with a TOTP code).
class LoginDialog extends StatelessWidget {
  const LoginDialog({super.key, required this.account, this.inAppBrowser = !kIsWeb});

  final BrokerAccount account;

  /// Whether an in-app browser is available (not on the web, where a page
  /// can't watch another site's redirect).
  final bool inAppBrowser;

  static Future<void> show(BuildContext context, BrokerAccount account, {bool inAppBrowser = !kIsWeb}) =>
      showDialog<void>(context: context, builder: (_) => LoginDialog(account: account, inAppBrowser: inAppBrowser));

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => LoginViewModel(account, sl(), sl(), sl(), sl()),
        child: _LoginBody(redirect: inAppBrowser ? LoginRedirect.forAccount(account) : null),
      );
}

class _LoginBody extends StatefulWidget {
  const _LoginBody({required this.redirect});

  /// Set when the login can be completed in the in-app browser.
  final LoginRedirect? redirect;

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

  /// Opens the broker's page in the system browser and waits for the server
  /// to finish the login.
  Future<void> _loginViaServer(LoginViewModel vm) async {
    await launchUrl(Uri.parse(vm.state.loginUrl),
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView);
    final ok = await vm.waitForLogin();
    if (ok && mounted) Navigator.pop(context);
  }

  /// Logs in on the broker's page inside the app, then creates the session
  /// from the redirect it returns.
  Future<void> _loginInApp(LoginViewModel vm, LoginRedirect redirect) async {
    final url = await BrokerLoginPage.open(
      context,
      title: vm.account.broker == BrokerType.zerodha ? 'Zerodha login' : 'Upstox login',
      loginUrl: vm.state.loginUrl,
      redirect: redirect,
    );
    if (url == null || !mounted) return;
    _input.text = url;
    await _submit(vm.loginWithRedirect);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final state = vm.state;
    final redirect = state.redirectLogin;
    final viaServer = redirect && state.loginFinishesOnServer;
    final inApp = viaServer ? null : widget.redirect;
    return AlertDialog(
      title: Text('Log in — ${vm.account.label}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (viaServer) ...[
                const Text('Sign in on the broker\'s page. When it says "Account linked", close it: '
                    'Srisarani Stocks picks up the login by itself.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: state.busy || state.waiting || state.loginUrl.isEmpty ? null : () => _loginViaServer(vm),
                  icon: const Icon(Icons.login),
                  label: const Text('Log in'),
                ),
                if (state.waiting) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Expanded(child: Text('Waiting for the broker login to finish…')),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text('If the page ends on another address:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
              ],
              if (inApp != null) ...[
                const Text('Sign in on the broker\'s page. Srisarani Stocks picks up the login by itself.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: state.busy || state.loginUrl.isEmpty ? null : () => _loginInApp(vm, inApp),
                  icon: const Icon(Icons.login),
                  label: const Text('Log in'),
                ),
                const SizedBox(height: 16),
                Text('Or log in in your browser:', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
              ],
              Text(redirect
                  ? '1. Open the broker login page and sign in.'
                  : '1. Open the Groww API keys page and approve today\'s access for this API key.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: state.loginUrl.isEmpty
                        ? null
                        : () => launchUrl(Uri.parse(state.loginUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(redirect ? (inApp != null ? 'Open in browser' : 'Open login page') : 'Open API keys page'),
                  ),
                  TextButton.icon(
                    onPressed:
                        state.loginUrl.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: state.loginUrl)),
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
      ),
      actions: [
        if (state.acceptsAccessToken)
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
