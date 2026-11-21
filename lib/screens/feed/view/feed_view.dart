import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/eps_signal.dart';
import '../../../common/domain/entities/eps_signals_config.dart';
import '../../../common/presentation/widgets/info_banner.dart';
import '../usecase/load_signals_feed_usecase.dart';
import '../viewmodel/feed_viewmodel.dart';
import 'widgets/eps_trade_card.dart';

/// Live NIFTY/SENSEX signals from Nexora's EMA Pivot rule.
class FeedView extends StatelessWidget {
  const FeedView({super.key, this.configured = EpsSignalsConfig.isConfigured});

  /// Overridable for tests; defaults to whether a signals proxy URL was
  /// baked in at build time (see [EpsSignalsConfig]).
  final bool configured;

  @override
  Widget build(BuildContext context) {
    if (!configured) return const _FeedNotConfigured();
    return ChangeNotifierProvider(
      // Eager: FeedViewModel starts its poll and ticker as soon as the tab
      // exists, not only once something reads it — lazy creation left a
      // provider never materialized if torn down before a first read, which
      // crashed on dispose (provider#tries to dispose a null value).
      lazy: false,
      create: (_) => FeedViewModel(sl<LoadSignalsFeedUseCase>()),
      child: const _FeedBody(),
    );
  }
}

class _FeedNotConfigured extends StatelessWidget {
  const _FeedNotConfigured();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signals', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        InfoBanner(
          text: 'The signals feed isn\'t set up yet. Deploy proxy/cloudflare-worker with an EPS_API_KEY secret, '
              'then build the app with --dart-define=EPS_SIGNALS_PROXY_URL=https://your-worker.workers.dev '
              '(see proxy/cloudflare-worker/README.md).',
          color: theme.colorScheme.secondaryContainer,
        ),
      ],
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedViewModel>();
    final state = vm.state;
    final theme = Theme.of(context);
    final symbols = state.feed?.symbols ?? const [];

    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text('Signals', style: theme.textTheme.headlineSmall)),
              if (state.loading)
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          InfoBanner(
            text: 'A tool reading from Nexora\'s EMA Pivot rule — not investment advice.',
            color: theme.colorScheme.secondaryContainer,
          ),
          if (state.lastUpdated != null) ...[
            const SizedBox(height: 4),
            Text('Updated ${DateFormat('HH:mm:ss').format(state.lastUpdated!)}', style: theme.textTheme.bodySmall),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              text: 'Couldn\'t load signals: ${state.error}',
              color: theme.colorScheme.errorContainer,
              action: TextButton(onPressed: vm.refresh, child: const Text('Retry')),
            ),
          ],
          if (!state.loading && state.isEmpty && state.error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No live NIFTY/SENSEX signals right now.')),
            ),
          for (final symbol in symbols) ..._symbolSection(symbol),
        ],
      ),
    );
  }

  List<Widget> _symbolSection(EpsSymbolSignals symbol) => [
        const SizedBox(height: 20),
        Text(
          symbol.price == null ? symbol.symbol : '${symbol.symbol}  ${symbol.price!.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        for (final rtf in symbol.ruleTimeframes) ..._ruleTimeframeSection(symbol.symbol, rtf),
      ];

  List<Widget> _ruleTimeframeSection(String symbolName, EpsRuleTimeframe rtf) {
    final rule = rtf.rule == EpsRule.ep ? 'EP' : 'EW';
    final label = '$symbolName · $rule · ${rtf.timeframe}';
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, left: 4),
        child: Text(rtf.bias == null ? label : '$label · Bias: ${rtf.bias}'),
      ),
      if (rtf.live != null)
        EpsTradeCard(label: label, trade: rtf.live!)
      else if (rtf.pending != null)
        EpsTradeCard(label: '$label (pending)', trade: rtf.pending!)
      else
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No live trade.')),
      for (final h in rtf.history) EpsTradeCard(label: label, trade: h),
    ];
  }
}
