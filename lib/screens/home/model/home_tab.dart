import 'package:flutter/material.dart';

enum HomeTab {
  signal('Signal', Icons.bolt_outlined, Icons.bolt),
  accounts('Accounts', Icons.key_outlined, Icons.key),
  activity('Activity', Icons.receipt_long_outlined, Icons.receipt_long),
  settings('Settings', Icons.tune_outlined, Icons.tune);

  const HomeTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
