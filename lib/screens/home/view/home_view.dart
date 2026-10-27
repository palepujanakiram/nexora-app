import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/di/injector.dart';
import '../../../common/domain/usecases/sync_from_server_usecase.dart';
import '../../../common/presentation/widgets/info_banner.dart';
import '../../accounts/view/accounts_view.dart';
import '../../activity/view/activity_view.dart';
import '../../settings/view/settings_view.dart';
import '../../signal/view/signal_view.dart';
import '../model/home_tab.dart';
import '../viewmodel/home_viewmodel.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        // Resolved per call: connecting to a server swaps the repositories.
        create: (_) => HomeViewModel(sync: () => sl<SyncFromServerUseCase>()()),
        child: const _HomeBody(),
      );
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  static const _pages = {
    HomeTab.signal: SignalView(),
    HomeTab.accounts: AccountsView(),
    HomeTab.activity: ActivityView(),
    HomeTab.settings: SettingsView(),
  };

  late final HomeViewModel _vm;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _vm = context.read<HomeViewModel>();
    // Back in the app: other devices may have placed orders or changed accounts.
    _lifecycle = AppLifecycleListener(onResume: _vm.sync);
    dataGeneration.addListener(_vm.sync);
  }

  @override
  void dispose() {
    dataGeneration.removeListener(_vm.sync);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                if (vm.syncError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: InfoBanner(
                      text: 'Couldn\'t load from the server: ${vm.syncError}',
                      color: Theme.of(context).colorScheme.errorContainer,
                      action: TextButton(onPressed: vm.sync, child: const Text('Retry')),
                    ),
                  ),
                Expanded(
                  // Rebuilt when the app connects to or leaves a server, so every
                  // screen's view model picks up the new repositories.
                  child: ValueListenableBuilder<int>(
                    valueListenable: dataGeneration,
                    builder: (context, generation, _) => IndexedStack(
                      key: ValueKey(generation),
                      // IndexedStack keeps each tab's state (e.g. a parsed signal) while switching.
                      index: vm.tab.index,
                      children: [for (final t in HomeTab.values) _pages[t]!],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: vm.tab.index,
        onDestinationSelected: (i) => vm.select(HomeTab.values[i]),
        destinations: [
          for (final t in HomeTab.values)
            NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
        ],
      ),
    );
  }
}
