import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/presentation/widgets/execution_result_card.dart';
import '../viewmodel/activity_viewmodel.dart';

class ActivityView extends StatelessWidget {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => ActivityViewModel(sl(), sl()),
        child: const _ActivityBody(),
      );
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final state = vm.state;
    final fmt = DateFormat('dd MMM, HH:mm:ss');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('Activity', style: Theme.of(context).textTheme.headlineSmall)),
            if (!state.isEmpty) TextButton(onPressed: vm.clear, child: const Text('Clear')),
          ],
        ),
        if (state.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Executed signals will appear here.')),
          ),
        for (final r in state.results) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Text('${fmt.format(r.time)} · ${r.signalText}',
                style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          ExecutionResultCard(result: r),
        ],
      ],
    );
  }
}
