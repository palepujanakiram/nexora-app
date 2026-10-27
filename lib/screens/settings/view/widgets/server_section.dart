import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/server_viewmodel.dart';
import 'server_connect_dialog.dart';

/// Settings → Server: connect this device to a nexora-backend server so all
/// devices share accounts and orders go out from the server's static IP.
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
        if (session == null) ...[
          const Text(
            'Connect to your nexora-backend server to use the same accounts on every device. '
            'Orders then go out from the server\'s static IP, the one you register with your brokers.',
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: state.busy ? null : () => ServerConnectDialog.show(context, vm),
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Connect to a server'),
          ),
        ] else ...[
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
                onPressed: state.busy ? null : () => _confirmDisconnect(context, vm),
                icon: const Icon(Icons.logout),
                label: const Text('Disconnect'),
              ),
            ],
          ),
        ],
        if (state.error != null && !state.busy) ...[
          const SizedBox(height: 8),
          Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, ServerViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect from the server?'),
        content: const Text(
          'This device goes back to the accounts stored on it. '
          'Your accounts and activity stay on the server for your other devices.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (ok == true) await vm.disconnect();
  }
}
