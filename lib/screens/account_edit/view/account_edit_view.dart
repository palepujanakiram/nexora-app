import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/broker_account.dart';
import '../model/account_form.dart';
import '../viewmodel/account_edit_viewmodel.dart';
import 'widgets/broker_selector.dart';
import 'widgets/broker_setup_help.dart';

class AccountEditView extends StatelessWidget {
  const AccountEditView({super.key, this.account});

  final BrokerAccount? account;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AccountEditViewModel(account, sl(), sl(), sl()),
        child: const _AccountEditBody(),
      );
}

class _AccountEditBody extends StatefulWidget {
  const _AccountEditBody();

  @override
  State<_AccountEditBody> createState() => _AccountEditBodyState();
}

class _AccountEditBodyState extends State<_AccountEditBody> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _save(AccountEditViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;
    await vm.save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete(AccountEditViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Remove "${vm.existing!.label}" and its stored keys from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await vm.delete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccountEditViewModel>();
    final form = vm.form;
    final guide = form.guide;
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isNew ? 'Add account' : 'Edit account'),
        actions: [
          if (!vm.isNew)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(vm)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BrokerSelector(
                  selected: form.broker,
                  onChanged: (b) => vm.update((f) => f.copyWith(broker: b)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: form.label,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. My Zerodha, Dad’s Upstox'),
                  validator: AccountForm.required,
                  onChanged: (v) => vm.update((f) => f.copyWith(label: v)),
                ),
                TextFormField(
                  initialValue: form.apiKey,
                  decoration: InputDecoration(labelText: guide.apiKeyLabel),
                  validator: AccountForm.required,
                  onChanged: (v) => vm.update((f) => f.copyWith(apiKey: v)),
                ),
                TextFormField(
                  initialValue: form.apiSecret,
                  obscureText: !vm.showSecret,
                  decoration: InputDecoration(
                    labelText: guide.apiSecretLabel,
                    helperText: vm.keepsStoredSecret ? 'Saved on the server. Leave empty to keep it.' : null,
                    suffixIcon: IconButton(
                      icon: Icon(vm.showSecret ? Icons.visibility_off : Icons.visibility),
                      onPressed: vm.toggleShowSecret,
                    ),
                  ),
                  validator: vm.keepsStoredSecret ? null : AccountForm.required,
                  onChanged: (v) => vm.update((f) => f.copyWith(apiSecret: v)),
                ),
                // Keyed so adding/removing this field doesn't hand its state to
                // the lots field below it.
                if (form.needsRedirectUri)
                  TextFormField(
                    key: const ValueKey('redirectUri'),
                    initialValue: form.redirectUri,
                    decoration: InputDecoration(
                      labelText: 'Redirect URI',
                      hintText: vm.callbackUrl ?? 'https://127.0.0.1/',
                      helperText: vm.callbackUrl == null
                          ? guide.redirectUriHelp
                          : 'Set this same address as the redirect URL in your ${guide.title} app',
                      helperMaxLines: 2,
                    ),
                    validator: AccountForm.required,
                    onChanged: (v) => vm.update((f) => f.copyWith(redirectUri: v)),
                  ),
                TextFormField(
                  key: const ValueKey('lots'),
                  initialValue: form.lots,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Lots per signal'),
                  validator: AccountForm.validateLots,
                  onChanged: (v) => vm.update((f) => f.copyWith(lots: v)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProductType>(
                  initialValue: form.product,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: [for (final p in ProductType.values) DropdownMenuItem(value: p, child: Text(p.label))],
                  onChanged: (p) => vm.update((f) => f.copyWith(product: p)),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: form.paperMode,
                  onChanged: (v) => vm.update((f) => f.copyWith(paperMode: v)),
                  title: const Text('Paper mode'),
                  subtitle: Text(form.paperMode
                      ? 'Orders are simulated — nothing is sent to the broker.'
                      : 'LIVE: orders will be placed with real money.'),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => _save(vm), child: const Text('Save')),
                const SizedBox(height: 24),
                BrokerSetupHelp(guide: guide),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
