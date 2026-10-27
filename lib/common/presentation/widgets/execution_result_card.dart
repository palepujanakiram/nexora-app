import 'package:flutter/material.dart';

import '../../domain/entities/execution_result.dart';

/// One account's outcome for a signal; used by the Signal and Activity screens.
class ExecutionResultCard extends StatelessWidget {
  const ExecutionResultCard({super.key, required this.result});

  final ExecutionResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(r.success ? Icons.check_circle : Icons.error, color: r.success ? Colors.green : scheme.error),
        title: Text('${r.accountLabel}${r.paper ? ' (paper)' : ''}'),
        subtitle: Text([
          r.broker,
          if (r.symbol != null) r.symbol!,
          if (r.quantity != null && r.entryPrice != null) 'Qty ${r.quantity} @ ${r.entryPrice!.toStringAsFixed(2)}',
          for (final o in r.orders) '${o.kind}: ${o.id}',
          if (r.error != null) r.error!,
        ].join('\n')),
        isThreeLine: true,
      ),
    );
  }
}
