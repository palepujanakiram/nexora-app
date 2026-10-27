import '../../../common/domain/entities/app_settings.dart';
import '../../../common/domain/repositories/settings_repository.dart';

/// Applies [change] to the current settings and saves them locally.
class UpdateSettingsUseCase {
  const UpdateSettingsUseCase(this._settings);

  final SettingsRepository _settings;

  Future<void> call(AppSettings Function(AppSettings current) change) => _settings.save(change(_settings.current));
}
