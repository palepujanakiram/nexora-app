import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        create: (_) => HomeViewModel(),
        child: const _HomeBody(),
      );
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  static const _pages = {
    HomeTab.signal: SignalView(),
    HomeTab.accounts: AccountsView(),
    HomeTab.activity: ActivityView(),
    HomeTab.settings: SettingsView(),
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            // IndexedStack keeps each tab's state (e.g. a parsed signal) while switching.
            child: IndexedStack(
              index: vm.tab.index,
              children: [for (final t in HomeTab.values) _pages[t]!],
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
