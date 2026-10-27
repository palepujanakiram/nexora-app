import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/broker_account.dart';
import '../../account_edit/view/account_edit_view.dart';
import '../viewmodel/accounts_viewmodel.dart';
import 'widgets/account_tile.dart';
import 'widgets/login_dialog.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AccountsViewModel(sl(), sl()),
        child: const _AccountsBody(),
      );
}

class _AccountsBody extends StatelessWidget {
  const _AccountsBody();

  void _openEditor(BuildContext context, [BrokerAccount? account]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => AccountEditView(account: account)));

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AccountsViewModel>();
    final state = vm.state;
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Broker accounts', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Add as many API keys per broker as you need. Sessions expire daily, so log in each morning.'),
          const SizedBox(height: 12),
          if (state.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No accounts yet.')),
            ),
          for (final (broker, accounts) in state.groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(broker.label, style: theme.textTheme.titleMedium),
            ),
            for (final a in accounts)
              AccountTile(
                account: a,
                onTap: () => _openEditor(context, a),
                onEnabledChanged: (v) => vm.setEnabled(a, v),
                onLogin: () => LoginDialog.show(context, a),
              ),
          ],
        ],
      ),
    );
  }
}
