import 'package:flutter/material.dart';

import '../../domain/entities/app_settings.dart';

abstract final class AppTheme {
  static ThemeData light(ThemeColor color) => ThemeData(colorSchemeSeed: Color(color.argb), useMaterial3: true);

  static ThemeData dark(ThemeColor color) =>
      ThemeData(colorSchemeSeed: Color(color.argb), brightness: Brightness.dark, useMaterial3: true);
}
