import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/local/preferences_datasource.dart';
import 'package:nexora_app/common/data/models/execution_result_model.dart';
import 'package:nexora_app/common/data/repositories/activity_repository_impl.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'activity_v1';

ExecutionResult _r(String label) => ExecutionResult(
      accountLabel: label,
      broker: 'Zerodha',
      signalText: 'sig',
      paper: true,
      time: DateTime.utc(2026, 10, 27),
    );

void main() {
  late PreferencesDataSource prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesDataSource(await SharedPreferences.getInstance());
  });

  List<String> stored() => [for (final e in prefs.readJson(_key)! as List) (e as Map)['accountLabel'] as String];

  test('starts empty when nothing is stored', () {
    expect(ActivityRepositoryImpl(prefs).current, isEmpty);
  });

  test('loads previously stored activity', () async {
    await prefs.writeJson(_key, [ExecutionResultModel.toJson(_r('old'))]);
    final repo = ActivityRepositoryImpl(prefs);
    expect(repo.current.single.accountLabel, 'old');
  });

  test('addAll puts new results first and persists them', () async {
    final repo = ActivityRepositoryImpl(prefs);
    await repo.addAll([_r('1')]);
    await repo.addAll([_r('2'), _r('3')]);
    expect(repo.current.map((r) => r.accountLabel), ['2', '3', '1']);
    expect(stored(), ['2', '3', '1']);
    expect(() => repo.current.add(_r('x')), throwsUnsupportedError);
    expect(ActivityRepositoryImpl(prefs).current.map((r) => r.accountLabel), ['2', '3', '1']);
  });

  test('keeps at most 200 entries, dropping the oldest', () async {
    final repo = ActivityRepositoryImpl(prefs);
    await repo.addAll([for (var i = 0; i < 150; i++) _r('old$i')]);
    await repo.addAll([for (var i = 0; i < 100; i++) _r('new$i')]);
    expect(repo.current, hasLength(200));
    expect(repo.current.first.accountLabel, 'new0');
    expect(repo.current[99].accountLabel, 'new99');
    expect(repo.current.last.accountLabel, 'old99');
    expect(stored(), hasLength(200));
  });

  test('clear empties memory and storage', () async {
    final repo = ActivityRepositoryImpl(prefs);
    await repo.addAll([_r('1')]);
    await repo.clear();
    expect(repo.current, isEmpty);
    expect(stored(), isEmpty);
  });

  test('watch emits the current value then changes', () async {
    final repo = ActivityRepositoryImpl(prefs);
    final emitted = <int>[];
    final sub = repo.watch().listen((l) => emitted.add(l.length));
    await pumpEventQueue();
    await repo.addAll([_r('1'), _r('2')]);
    await repo.clear();
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted, [0, 2, 0]);
  });
}
