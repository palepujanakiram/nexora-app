import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/home/model/home_tab.dart';
import 'package:nexora_app/screens/home/viewmodel/home_viewmodel.dart';

void main() {
  test('starts on Signal and notifies only on an actual change', () {
    final vm = HomeViewModel();
    var notified = 0;
    vm.addListener(() => notified++);

    expect(vm.tab, HomeTab.signal);
    vm.select(HomeTab.signal);
    expect(notified, 0);

    vm.select(HomeTab.activity);
    expect(vm.tab, HomeTab.activity);
    expect(notified, 1);

    vm.select(HomeTab.activity);
    expect(notified, 1);
  });

  group('with a server', () {
    test('syncs on start and when Accounts or Activity is opened', () async {
      var syncs = 0;
      final vm = HomeViewModel(sync: () async {
        syncs++;
        return null;
      });
      await pumpEventQueue();
      expect(syncs, 1);
      vm.select(HomeTab.settings);
      await pumpEventQueue();
      expect(syncs, 1, reason: 'Settings needs no fresh data');
      vm.select(HomeTab.accounts);
      await pumpEventQueue();
      vm.select(HomeTab.activity);
      await pumpEventQueue();
      expect(syncs, 3);
      expect(vm.syncError, isNull);
    });

    test('reports a failed sync until one works, and skips overlapping syncs', () async {
      String? result = 'Couldn\'t reach the server';
      var syncs = 0;
      final vm = HomeViewModel(sync: () async {
        syncs++;
        return result;
      });
      var notified = 0;
      vm.addListener(() => notified++);
      await pumpEventQueue();
      expect(vm.syncError, 'Couldn\'t reach the server');

      await Future.wait([vm.sync(), vm.sync()]);
      expect(syncs, 2, reason: 'the second call overlapped the first');
      expect(notified, 1, reason: 'same error, no change');

      result = null;
      await vm.sync();
      expect(vm.syncError, isNull);
    });

    test('a sync that finishes after dispose is ignored', () async {
      final vm = HomeViewModel(sync: () async => 'late');
      vm.dispose();
      await pumpEventQueue();
      expect(vm.syncError, isNull);
    });
  });
}
