import '../../domain/entities/execution_result.dart';
import '../../domain/repositories/activity_repository.dart';
import '../../utils/reactive_cache.dart';
import '../datasources/local/preferences_datasource.dart';
import '../models/execution_result_model.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(this._prefs) : _cache = ReactiveCache(_read(_prefs));

  static const _key = 'activity_v1';
  static const _maxEntries = 200;

  final PreferencesDataSource _prefs;
  final ReactiveCache<List<ExecutionResult>> _cache;

  static List<ExecutionResult> _read(PreferencesDataSource prefs) {
    final raw = prefs.readJson(_key) as List? ?? const [];
    return [for (final e in raw) ExecutionResultModel.fromJson(Map<String, dynamic>.from(e as Map))];
  }

  @override
  List<ExecutionResult> get current => _cache.value;

  @override
  Stream<List<ExecutionResult>> watch() => _cache.watch();

  @override
  Future<void> addAll(List<ExecutionResult> results) => _persist([...results, ...current].take(_maxEntries).toList());

  @override
  Future<void> clear() => _persist(const []);

  Future<void> _persist(List<ExecutionResult> activity) {
    _cache.value = List.unmodifiable(activity);
    return _prefs.writeJson(_key, [for (final r in activity) ExecutionResultModel.toJson(r)]);
  }
}
