import '../../domain/entities/app_settings.dart';

/// JSON mapping for [AppSettings]. Unknown or missing values fall back to
/// defaults so older saved settings keep loading.
abstract final class AppSettingsModel {
  static Map<String, dynamic> toJson(AppSettings s) => {
        'entryPriceMode': s.entryPriceMode.name,
        'exitMode': s.exitMode.name,
        'targetIndex': s.targetIndex,
        'corsProxy': s.corsProxy,
        'themeColor': s.themeColor.name,
      };

  static AppSettings fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    return AppSettings(
      entryPriceMode: _byName(EntryPriceMode.values, j['entryPriceMode'], d.entryPriceMode),
      exitMode: _byName(ExitMode.values, j['exitMode'], d.exitMode),
      targetIndex: j['targetIndex'] as int? ?? d.targetIndex,
      corsProxy: j['corsProxy'] as String? ?? d.corsProxy,
      themeColor: _byName(ThemeColor.values, j['themeColor'], d.themeColor),
    );
  }

  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;
}
