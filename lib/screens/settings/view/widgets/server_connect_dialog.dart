import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/server_viewmodel.dart';

/// Signs in to a nexora-backend server, or creates a login with an invite code.
class ServerConnectDialog extends StatefulWidget {
  const ServerConnectDialog({super.key});

  static Future<void> show(BuildContext context, ServerViewModel vm) {
    vm.clearError();
    return showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const ServerConnectDialog()),
    );
  }

  @override
  State<ServerConnectDialog> createState() => _ServerConnectDialogState();
}

class _ServerConnectDialogState extends State<ServerConnectDialog> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  bool _newLogin = false;

  @override
  void dispose() {
    for (final c in [_url, _email, _password, _invite]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _submit(ServerViewModel vm) async {
    if (!_form.currentState!.validate()) return;
    final ok = await vm.connect(
      url: _url.text,
      email: _email.text,
      password: _password.text,
      inviteCode: _newLogin ? _invite.text : null,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ServerViewModel>();
    final state = vm.state;
    return AlertDialog(
      title: Text(_newLogin ? 'Create a server login' : 'Connect to a server'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Server address', hintText: 'https://your-app.fly.dev'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _required,
                ),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: _newLogin ? 'At least 10 characters.' : null,
                  ),
                  validator: _required,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _newLogin,
                  onChanged: (v) => setState(() => _newLogin = v),
                  title: const Text('I\'m new: create my login'),
                  subtitle: const Text('Needs the invite code from whoever runs the server.'),
                ),
                if (_newLogin)
                  TextFormField(
                    controller: _invite,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Invite code'),
                    validator: _required,
                  ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: state.busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: state.busy ? null : () => _submit(vm),
          child: state.busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_newLogin ? 'Create login' : 'Sign in'),
        ),
      ],
    );
  }
}
