import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/app_settings.dart';
import '../model/settings_state.dart';
import '../viewmodel/settings_viewmodel.dart';
import 'widgets/cors_proxy_help.dart';
import 'widgets/theme_color_picker.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => SettingsViewModel(sl(), sl(), sl(), sl()),
        child: const _SettingsBody(),
      );
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  late final _proxy = TextEditingController(text: context.read<SettingsViewModel>().state.settings.corsProxy);

  @override
  void dispose() {
    _proxy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final state = vm.state;
    final s = state.settings;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text('Theme colour', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        ThemeColorPicker(selected: s.themeColor, onSelected: vm.setThemeColor),
        const Divider(height: 40),
        Text('Limit price within the entry range', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<EntryPriceMode>(
          segments: [for (final m in EntryPriceMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {s.entryPriceMode},
          onSelectionChanged: (v) => vm.setEntryPriceMode(v.first),
        ),
        const SizedBox(height: 24),
        Text('Exit orders', style: theme.textTheme.titleSmall),
        RadioGroup<ExitMode>(
          groupValue: s.exitMode,
          onChanged: (v) => vm.setExitMode(v!),
          child: Column(
            children: [
              for (final m in ExitMode.values)
                RadioListTile<ExitMode>(contentPadding: EdgeInsets.zero, value: m, title: Text(m.label)),
            ],
          ),
        ),
        if (state.showTargetPicker) ...[
          Text('Target used for the GTT exit', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final i in SettingsState.targetChoices) ButtonSegment(value: i, label: Text('TGT${i + 1}')),
            ],
            selected: {s.targetIndex},
            onSelectionChanged: (v) => vm.setTargetIndex(v.first),
          ),
          const SizedBox(height: 4),
          Text('Falls back to the last target if the signal has fewer.', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
        Text('Web CORS proxy', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _proxy,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'https://nexora-cors-proxy.<you>.workers.dev',
            helperText: state.isWeb
                ? 'Browsers block direct calls to broker APIs, so the web app needs your own proxy.'
                : 'Not needed on iOS/Android — leave empty.',
            helperMaxLines: 3,
          ),
          onSubmitted: vm.setCorsProxy,
          onTapOutside: (_) => vm.setCorsProxy(_proxy.text),
        ),
        if (state.isWeb) ...[
          const SizedBox(height: 12),
          _ProxyTestRow(state: state, onTest: () => vm.testProxy(_proxy.text)),
          const SizedBox(height: 16),
          CorsProxyHelp(
            loadWorkerScript: vm.workerScript,
            initiallyExpanded: s.corsProxy.isEmpty,
          ),
        ],
      ],
    );
  }
}

class _ProxyTestRow extends StatelessWidget {
  const _ProxyTestRow({required this.state, required this.onTest});

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
