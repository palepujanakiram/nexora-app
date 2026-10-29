import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/server_viewmodel.dart';
import 'change_password_dialog.dart';

/// Settings → Server: the signed-in user, the server's static IP to register
/// with brokers, changing the password and signing out.
class ServerSection extends StatelessWidget {
  const ServerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ServerViewModel>();
    final state = vm.state;
    final theme = Theme.of(context);
    final session = state.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Server', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (session != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done, color: Colors.green),
            title: Text('Signed in as ${session.email}'),
            subtitle: Text(session.url),
          ),
        if (state.serverIp != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Server IP: ${state.serverIp}'),
            subtitle: const Text('Register this as the static IP with each broker.'),
            trailing: IconButton(
              tooltip: 'Copy IP',
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: state.serverIp!)),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (state.serverIp == null)
              TextButton.icon(
                onPressed: state.loadingIp ? null : vm.loadServerIp,
                icon: const Icon(Icons.public),
                label: const Text('Show server IP'),
              ),
            TextButton.icon(
              onPressed: state.busy ? null : () => _changePassword(context, vm),
              icon: const Icon(Icons.password),
              label: const Text('Change password'),
            ),
            TextButton.icon(
              onPressed: state.busy ? null : () => _confirmSignOut(context, vm),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
        if (state.error != null && !state.busy) ...[
          const SizedBox(height: 8),
          Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  Future<void> _changePassword(BuildContext context, ServerViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await ChangePasswordDialog.show(context, vm)) {
      messenger.showSnackBar(const SnackBar(content: Text('Password changed. Other devices were signed out.')));
    }
  }

  Future<void> _confirmSignOut(BuildContext context, ServerViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll need to sign in again to use the app. '
          'Your accounts and activity stay on the server.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await vm.signOut();
  }
}
