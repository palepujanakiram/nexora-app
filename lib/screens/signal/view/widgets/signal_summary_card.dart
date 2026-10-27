import 'package:flutter/material.dart';

import '../../../../common/presentation/widgets/info_banner.dart';
import '../../model/signal_state.dart';

class SignalSummaryCard extends StatelessWidget {
  const SignalSummaryCard({super.key, required this.state});

  final SignalState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signal = state.signal!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(signal.side),
                  backgroundColor: signal.isBuy ? Colors.green.shade100 : Colors.red.shade100,
                  labelStyle: TextStyle(color: signal.isBuy ? Colors.green.shade900 : Colors.red.shade900),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(signal.contractLabel, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            _row('Exchange', signal.exchange),
            _row('Entry range', signal.entryLabel),
            _row('Limit price',
                '${state.limitPrice!.toStringAsFixed(2)} (${state.settings.entryPriceMode.label.toLowerCase()})'),
            _row('Stop loss', signal.stopLoss?.toString() ?? '—'),
            _row('Targets', signal.targets.isEmpty ? '—' : signal.targets.join(', ')),
            _row('Exits', state.placesExits ? 'GTT: SL ${signal.stopLoss} / TGT ${state.exitTarget}' : 'None (entry only)'),
            for (final w in signal.warnings) ...[
              const SizedBox(height: 8),
              InfoBanner(text: w, color: theme.colorScheme.tertiaryContainer),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [SizedBox(width: 110, child: Text(k)), Expanded(child: Text(v))]),
      );
}
