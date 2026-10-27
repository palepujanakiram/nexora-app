import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/local/preferences_datasource.dart';
import 'package:nexora_app/common/data/repositories/settings_repository_impl.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'app_settings_v1';

void main() {
  Future<PreferencesDataSource> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return PreferencesDataSource(await SharedPreferences.getInstance());
  }

  test('defaults when nothing is stored', () async {
    final s = SettingsRepositoryImpl(await prefsWith({})).current;
    expect(s.entryPriceMode, EntryPriceMode.high);
    expect(s.exitMode, ExitMode.withStopAndTarget);
    expect(s.targetIndex, 0);
    expect(s.corsProxy, '');
    expect(s.themeColor, ThemeColor.green);
  });

  test('defaults when stored value is not a JSON object', () async {
    final s = SettingsRepositoryImpl(await prefsWith({_key: '[1,2]'})).current;
    expect(s.themeColor, ThemeColor.green);
  });

  test('loads stored settings', () async {
    final repo = SettingsRepositoryImpl(
      await prefsWith({_key: '{"entryPriceMode":"low","exitMode":"entryOnly","targetIndex":1,"corsProxy":"p/","themeColor":"teal"}'}),
    );
    expect(repo.current.entryPriceMode, EntryPriceMode.low);
    expect(repo.current.exitMode, ExitMode.entryOnly);
    expect(repo.current.targetIndex, 1);
    expect(repo.current.corsProxy, 'p/');
    expect(repo.current.themeColor, ThemeColor.teal);
  });

  test('save updates memory, persists and emits', () async {
    final prefs = await prefsWith({});
    final repo = SettingsRepositoryImpl(prefs);
    final emitted = <ThemeColor>[];
    final sub = repo.watch().listen((s) => emitted.add(s.themeColor));
    await pumpEventQueue();
    await repo.save(const AppSettings(themeColor: ThemeColor.purple, corsProxy: 'https://x/'));
    await pumpEventQueue();
    await sub.cancel();

    expect(repo.current.themeColor, ThemeColor.purple);
    expect(emitted, [ThemeColor.green, ThemeColor.purple]);
    expect((prefs.readJson(_key)! as Map)['themeColor'], 'purple');
    final reloaded = SettingsRepositoryImpl(prefs).current;
    expect(reloaded.themeColor, ThemeColor.purple);
    expect(reloaded.corsProxy, 'https://x/');
  });
}
