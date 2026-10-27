import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/home/model/home_tab.dart';

void main() {
  test('tabs are in navigation order with labels and icons', () {
    expect(HomeTab.values.map((t) => t.label), ['Signal', 'Accounts', 'Activity', 'Settings']);
    expect(HomeTab.signal.icon, Icons.bolt_outlined);
    expect(HomeTab.signal.selectedIcon, Icons.bolt);
    expect(HomeTab.accounts.selectedIcon, Icons.key);
    expect(HomeTab.activity.icon, Icons.receipt_long_outlined);
    expect(HomeTab.settings.selectedIcon, Icons.tune);
  });
}
