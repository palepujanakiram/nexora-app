import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/server_viewmodel.dart';

/// Changes the server password. Other devices are signed out.
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  /// Returns true when the password was changed.
  static Future<bool> show(BuildContext context, ServerViewModel vm) async {
    vm.clearError();
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: const ChangePasswordDialog()),
    );
    return changed ?? false;
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(ServerViewModel vm) async {
    if (!_form.currentState!.validate()) return;
    final ok = await vm.changePassword(currentPassword: _current.text, newPassword: _next.text);
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ServerViewModel>();
    final state = vm.state;
    return AlertDialog(
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _current,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Current password'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _next,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 10 characters.'),
                  validator: (v) => (v == null || v.length < 10) ? 'Use at least 10 characters.' : null,
                ),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Repeat new password'),
                  validator: (v) => v != _next.text ? 'The passwords don\'t match.' : null,
                ),
                const SizedBox(height: 12),
                const Text('Your other devices will be signed out.'),
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
        TextButton(onPressed: state.busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: state.busy ? null : () => _submit(vm),
          child: state.busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Change password'),
        ),
      ],
    );
  }
}
