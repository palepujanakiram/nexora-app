import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../utils/reactive_cache.dart';
import '../datasources/local/preferences_datasource.dart';
import '../models/app_settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs) : _cache = ReactiveCache(_read(_prefs));

  static const _key = 'app_settings_v1';

  final PreferencesDataSource _prefs;
  final ReactiveCache<AppSettings> _cache;

  static AppSettings _read(PreferencesDataSource prefs) {
    final raw = prefs.readJson(_key);
    return raw is Map ? AppSettingsModel.fromJson(Map<String, dynamic>.from(raw)) : const AppSettings();
  }

  @override
  AppSettings get current => _cache.value;

  @override
  Stream<AppSettings> watch() => _cache.watch();

  @override
  Future<void> save(AppSettings settings) {
    _cache.value = settings;
    return _prefs.writeJson(_key, AppSettingsModel.toJson(settings));
  }
}
