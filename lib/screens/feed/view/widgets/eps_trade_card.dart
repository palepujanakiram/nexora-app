import 'package:flutter/material.dart';

import '../../../../common/domain/entities/eps_signal.dart';

/// One EMA Pivot trade (live or from history).
class EpsTradeCard extends StatelessWidget {
  const EpsTradeCard({super.key, required this.label, required this.trade});

  /// e.g. 'NIFTY · 30m'.
  final String label;
  final EpsTrade trade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = trade;
    final isCall = t.side.contains('CE');
    final statusColor = switch (t.status) {
      EpsTradeStatus.active => theme.colorScheme.primary,
      EpsTradeStatus.t1 || EpsTradeStatus.t2 => Colors.green,
      EpsTradeStatus.stopped => theme.colorScheme.error,
      EpsTradeStatus.invalidated => Colors.grey,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(t.side),
                  backgroundColor: isCall ? Colors.green.shade100 : Colors.red.shade100,
                  labelStyle: TextStyle(color: isCall ? Colors.green.shade900 : Colors.red.shade900),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
                Chip(
                  label: Text(t.status.name.toUpperCase()),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _row('Entry', t.entry.toStringAsFixed(2)),
            _row(
              'Stop',
              t.stop == t.initialStop
                  ? t.stop.toStringAsFixed(2)
                  : '${t.stop.toStringAsFixed(2)} (moved from ${t.initialStop.toStringAsFixed(2)}, ${t.stopMoveCount}x)',
            ),
            _row(
              'Targets',
              t.targets.isEmpty
                  ? '—'
                  : t.targets.map((g) => g.hit ? '${g.price.toStringAsFixed(2)} ✓' : g.price.toStringAsFixed(2)).join('  '),
            ),
            if (t.points != null) _row('P/L', '${t.points!.toStringAsFixed(2)} pts${t.r != null ? ' (${t.r!.toStringAsFixed(2)}R)' : ''}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [SizedBox(width: 90, child: Text(k)), Expanded(child: Text(v))]),
      );
}
