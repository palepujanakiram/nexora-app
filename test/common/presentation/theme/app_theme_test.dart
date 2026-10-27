import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/presentation/theme/app_theme.dart';

void main() {
  for (final c in [ThemeColor.green, ThemeColor.red]) {
    test('light theme for ${c.name} is Material 3, light and seeded from the colour', () {
      final t = AppTheme.light(c);
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.light);
      expect(t.colorScheme, ColorScheme.fromSeed(seedColor: Color(c.argb)));
    });

    test('dark theme for ${c.name} is Material 3, dark and seeded from the colour', () {
      final t = AppTheme.dark(c);
      expect(t.useMaterial3, isTrue);
      expect(t.brightness, Brightness.dark);
      expect(t.colorScheme, ColorScheme.fromSeed(seedColor: Color(c.argb), brightness: Brightness.dark));
    });
  }

  test('different seed colours give different primaries', () {
    expect(AppTheme.light(ThemeColor.green).colorScheme.primary,
        isNot(AppTheme.light(ThemeColor.red).colorScheme.primary));
  });
}
