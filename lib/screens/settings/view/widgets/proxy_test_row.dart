import 'package:flutter/material.dart';

import '../../model/settings_state.dart';

/// "Test proxy" button with the result of the last check next to it.
class ProxyTestRow extends StatelessWidget {
  const ProxyTestRow({super.key, required this.state, required this.onTest});

  final SettingsState state;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = state.proxyTestMessage;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: state.testingProxy ? null : onTest,
          icon: state.testingProxy
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.network_check),
          label: const Text('Test proxy'),
        ),
        if (message != null) ...[
          const SizedBox(width: 12),
          Icon(state.proxyTestPassed ? Icons.check_circle : Icons.error_outline,
              color: state.proxyTestPassed ? Colors.green : scheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ],
    );
  }
}
