import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  AppSettings get current;

  /// Emits the current settings, then every change.
  Stream<AppSettings> watch();

  Future<void> save(AppSettings settings);
}
