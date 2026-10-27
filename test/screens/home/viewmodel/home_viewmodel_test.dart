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
}
