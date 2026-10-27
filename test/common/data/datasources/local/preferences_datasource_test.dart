import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/local/preferences_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('readJson returns null for a missing key', () async {
    final ds = PreferencesDataSource(await SharedPreferences.getInstance());
    expect(ds.readJson('missing'), isNull);
  });

  test('writeJson stores JSON text and readJson decodes it', () async {
    final prefs = await SharedPreferences.getInstance();
    final ds = PreferencesDataSource(prefs);
    await ds.writeJson('k', {
      'a': 1,
      'b': [true, 'x'],
    });
    expect(prefs.getString('k'), '{"a":1,"b":[true,"x"]}');
    expect(ds.readJson('k'), {
      'a': 1,
      'b': [true, 'x'],
    });
  });

  test('readJson decodes values stored before the data source was created', () async {
    SharedPreferences.setMockInitialValues({'list': '[1,2,3]'});
    final ds = PreferencesDataSource(await SharedPreferences.getInstance());
    expect(ds.readJson('list'), [1, 2, 3]);
  });

  test('readJson throws on corrupt JSON', () async {
    SharedPreferences.setMockInitialValues({'bad': '{not json'});
    final ds = PreferencesDataSource(await SharedPreferences.getInstance());
    expect(() => ds.readJson('bad'), throwsFormatException);
  });
}
