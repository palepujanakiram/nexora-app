import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/local/secure_storage_datasource.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('with the default storage', () {
    test('readJson returns null for a missing key', () async {
      expect(await SecureStorageDataSource().readJson('missing'), isNull);
    });

    test('writeJson then readJson round-trips a value', () async {
      final ds = SecureStorageDataSource();
      await ds.writeJson('k', [
        {'id': 'a', 'n': 2},
      ]);
      expect(await ds.readJson('k'), [
        {'id': 'a', 'n': 2},
      ]);
    });
  });

  group('with an injected storage', () {
    test('writes JSON-encoded text under the key', () async {
      const storage = FlutterSecureStorage();
      final ds = SecureStorageDataSource(storage);
      await ds.writeJson('k', {'token': 't'});
      expect(await storage.read(key: 'k'), '{"token":"t"}');
    });

    test('decodes pre-existing values', () async {
      FlutterSecureStorage.setMockInitialValues({'k': '{"x":true}'});
      final ds = SecureStorageDataSource(const FlutterSecureStorage());
      expect(await ds.readJson('k'), {'x': true});
    });

    test('throws on corrupt JSON', () async {
      FlutterSecureStorage.setMockInitialValues({'k': 'nope'});
      final ds = SecureStorageDataSource(const FlutterSecureStorage());
      await expectLater(ds.readJson('k'), throwsFormatException);
    });
  });

  test('delete removes a stored value', () async {
    final ds = SecureStorageDataSource();
    await ds.writeJson('k', 1);
    await ds.delete('k');
    expect(await ds.readJson('k'), isNull);
  });
}
