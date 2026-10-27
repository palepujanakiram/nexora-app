import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/execution_result.dart';
import '../../../common/presentation/widgets/account_badges.dart';
import '../../../common/presentation/widgets/execution_result_card.dart';
import '../../../common/presentation/widgets/info_banner.dart';
import '../model/signal_state.dart';
import '../viewmodel/signal_viewmodel.dart';
import 'widgets/signal_summary_card.dart';

class SignalView extends StatelessWidget {
  const SignalView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => SignalViewModel(sl(), sl(), sl(), sl()),
        child: const _SignalBody(),
      );
}

class _SignalBody extends StatefulWidget {
  const _SignalBody();

  @override
  State<_SignalBody> createState() => _SignalBodyState();
}

class _SignalBodyState extends State<_SignalBody> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _parse(SignalViewModel vm) {
    _hideKeyboard();
    vm.parse(_controller.text);
  }

  Future<void> _confirmAndExecute(SignalViewModel vm) async {
    final state = vm.state;
    final live = state.chosenLive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(live.isEmpty ? 'Run paper trade?' : 'Place LIVE orders?'),
        content: Text(
          '${state.signal!.side} ${state.signal!.contractLabel}\n\n'
          '${state.chosen.length} account(s): ${state.chosen.map((a) => a.label).join(', ')}'
          '${live.isEmpty ? '' : '\n\n${live.length} account(s) will send real orders to the broker.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: live.isEmpty ? null : FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(live.isEmpty ? 'Run' : 'Place orders'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final results = await vm.execute();
    if (mounted) await _showResults(vm, results);
  }

  Future<void> _showResults(SignalViewModel vm, List<ExecutionResult> results) async {
    // Accounts the server refused because this signal was already placed on them.
    final duplicates = {for (final r in results) if (r.isDuplicate && r.accountId != null) r.accountId!};
    final placeAnyway = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Results', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final r in results) ExecutionResultCard(result: r),
            if (duplicates.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.replay),
                label: Text('Place anyway on ${duplicates.length} account(s)'),
              ),
            ],
          ],
        ),
      ),
    );
    if (placeAnyway != true) return;
    final again = await vm.execute(accountIds: duplicates, allowDuplicate: true);
    if (mounted) await _showResults(vm, again);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignalViewModel>();
    final state = vm.state;

    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text('New signal', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          // Signals are one line: the keyboard's action key is "Done" (it
          // closes the keyboard and parses) instead of inserting a newline.
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _parse(vm),
          onTapOutside: (_) => _hideKeyboard(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'BUY SENSEX 29 OCT 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600',
            suffixIcon: IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                vm.clear();
              },
            ),
          ),
          onChanged: vm.onTextChanged,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => _parse(vm),
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Parse signal'),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          InfoBanner(text: state.error!, color: Theme.of(context).colorScheme.errorContainer),
        ],
        if (state.signal != null) ..._signalSection(context, vm, state),
      ],
    );
  }

  List<Widget> _signalSection(BuildContext context, SignalViewModel vm, SignalState state) => [
        const SizedBox(height: 16),
        SignalSummaryCard(state: state),
        const SizedBox(height: 16),
        Text('Execute on', style: Theme.of(context).textTheme.titleMedium),
        if (state.accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No broker accounts yet — add one in the Accounts tab.'),
          ),
        for (final a in state.accounts)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: state.isSelected(a),
            onChanged: (v) => vm.setSelected(a.id, v ?? false),
            title: Text(a.label),
            subtitle: Text('${a.broker.label} · ${a.lots} lot(s)'),
            secondary: AccountBadges(account: a),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: state.canExecute ? () => _confirmAndExecute(vm) : null,
          icon: state.busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: Text('${state.signal!.side} on ${state.chosen.length} account(s)'),
        ),
      ];
}
