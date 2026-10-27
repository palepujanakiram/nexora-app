import 'package:flutter/material.dart';

import '../../../../common/domain/entities/broker_account.dart';
import '../../../../common/presentation/widgets/account_badges.dart';

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.onTap,
    required this.onEnabledChanged,
    required this.onLogin,
  });

  final BrokerAccount account;
  final VoidCallback onTap;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(a.label),
            subtitle: Text('Key ${a.maskedKey} · ${a.lots} lot(s) · ${a.product.label}'),
            trailing: AccountBadges(account: a),
            onTap: onTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Switch(value: a.enabled, onChanged: onEnabledChanged),
                const Text('Use by default'),
                const Spacer(),
                TextButton.icon(
                  onPressed: onLogin,
                  icon: const Icon(Icons.login),
                  label: Text(a.hasValidToken ? 'Re-login' : 'Login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
