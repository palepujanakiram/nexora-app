import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/entities/app_settings.dart';
import '../model/settings_state.dart';
import '../viewmodel/server_viewmodel.dart';
import '../viewmodel/settings_viewmodel.dart';
import 'widgets/cors_proxy_help.dart';
import 'widgets/proxy_test_row.dart';
import 'widgets/server_section.dart';
import 'widgets/theme_color_picker.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, this.isWeb = kIsWeb});

  /// Shows the web-only proxy tools; overridable for tests.
  final bool isWeb;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsViewModel(sl(), sl(), sl(), sl(), isWeb: isWeb)),
          ChangeNotifierProvider(create: (_) => ServerViewModel(sl(), sl(), sl())),
        ],
        child: const _SettingsBody(),
      );
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody();

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  late final SettingsViewModel _vm;
  late final TextEditingController _proxy;

  /// The saved proxy URL the field was last synced to.
  late String _syncedProxy;

  @override
  void initState() {
    super.initState();
    _vm = context.read<SettingsViewModel>();
    _syncedProxy = _vm.state.settings.corsProxy;
    _proxy = TextEditingController(text: _syncedProxy);
    _vm.addListener(_syncProxyField);
  }

  // The saved settings arrive after the first build, so the field must follow
  // them; otherwise it starts empty and saving it would erase the stored URL.
  void _syncProxyField() {
    final saved = _vm.state.settings.corsProxy;
    if (saved == _syncedProxy) return;
    _syncedProxy = saved;
    if (_proxy.text.trim() != saved) _proxy.text = saved;
  }

  @override
  void dispose() {
    _vm.removeListener(_syncProxyField);
    _proxy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final state = vm.state;
    final s = state.settings;
    final theme = Theme.of(context);
    final connected = context.select<ServerViewModel, bool>((s) => s.state.connected);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        const ServerSection(),
        const Divider(height: 40),
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
        if (connected) ...[
          const SizedBox(height: 8),
          Text('The server places the entry order only. Set the stop loss and target in the broker\'s app.',
              style: theme.textTheme.bodySmall),
        ] else
          ..._exitSection(vm, state, theme),
        // A connected server reaches the brokers itself; the proxy isn't used.
        if (!connected) ..._proxySection(vm, state, theme),
      ],
    );
  }

  /// Stop loss and target orders (GTT), placed only when working without a server.
  List<Widget> _exitSection(SettingsViewModel vm, SettingsState state, ThemeData theme) {
    final s = state.settings;
    return [
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
    ];
  }

  List<Widget> _proxySection(SettingsViewModel vm, SettingsState state, ThemeData theme) {
    final s = state.settings;
    return [
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
        ProxyTestRow(state: state, onTest: () => vm.testProxy(_proxy.text)),
        const SizedBox(height: 16),
        CorsProxyHelp(loadWorkerScript: vm.workerScript, initiallyExpanded: s.corsProxy.isEmpty),
      ],
    ];
  }
}
