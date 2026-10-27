import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret local data (settings, activity log).
class PreferencesDataSource {
  PreferencesDataSource(this._prefs);

  final SharedPreferences _prefs;

  Object? readJson(String key) {
    final raw = _prefs.getString(key);
    return raw == null ? null : jsonDecode(raw);
  }

  Future<void> writeJson(String key, Object value) => _prefs.setString(key, jsonEncode(value));
}
