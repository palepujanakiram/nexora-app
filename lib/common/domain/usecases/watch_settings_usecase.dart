import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// Shared by the app shell (theme), Signal and Settings screens.
class WatchSettingsUseCase {
  const WatchSettingsUseCase(this._settings);

  final SettingsRepository _settings;

  Stream<AppSettings> call() => _settings.watch();
}
