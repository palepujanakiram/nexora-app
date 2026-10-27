import 'package:flutter/material.dart';

import '../../../../common/domain/entities/broker_account.dart';
import '../../model/broker_setup_guide.dart';

/// One radio option per supported broker.
class BrokerSelector extends StatelessWidget {
  const BrokerSelector({super.key, required this.selected, required this.onChanged});

  final BrokerType selected;
  final ValueChanged<BrokerType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock broker', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: RadioGroup<BrokerType>(
            groupValue: selected,
            onChanged: (b) => onChanged(b!),
            child: Column(
              children: [
                for (final b in BrokerType.values)
                  RadioListTile<BrokerType>(
                    value: b,
                    title: Text(BrokerSetupGuide.of(b).title),
                    subtitle: Text(BrokerSetupGuide.of(b).subtitle),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
