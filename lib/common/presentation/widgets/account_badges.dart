import 'package:flutter/material.dart';

import '../../domain/entities/broker_account.dart';

/// PAPER/LIVE and logged-in/out pills shown next to an account.
class AccountBadges extends StatelessWidget {
  const AccountBadges({super.key, required this.account});

  final BrokerAccount account;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(account.paperMode ? 'PAPER' : 'LIVE',
            account.paperMode ? scheme.secondaryContainer : scheme.errorContainer),
        const SizedBox(height: 4),
        _pill(account.hasValidToken ? 'Logged in' : 'Logged out',
            account.hasValidToken ? Colors.green.withValues(alpha: 0.2) : scheme.surfaceContainerHighest),
      ],
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
