import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/local/secure_storage_datasource.dart';
import 'package:nexora_app/common/data/models/broker_account_model.dart';
import 'package:nexora_app/common/data/repositories/account_repository_impl.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';

const _key = 'broker_accounts_v1';

BrokerAccount _acc(String id, {String label = 'L'}) =>
    BrokerAccount(id: id, broker: BrokerType.zerodha, label: label, apiKey: 'k$id', apiSecret: 's$id');

Future<List<String>> _storedIds(SecureStorageDataSource ds) async =>
    [for (final e in (await ds.readJson(_key))! as List) (e as Map)['id'] as String];

void main() {
  late SecureStorageDataSource storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageDataSource(const FlutterSecureStorage());
  });

  test('load with nothing stored starts empty', () async {
    final repo = await AccountRepositoryImpl.load(storage);
    expect(repo.current, isEmpty);
  });

  test('load reads previously stored accounts', () async {
    await storage.writeJson(_key, [BrokerAccountModel.toJson(_acc('a')), BrokerAccountModel.toJson(_acc('b'))]);
    final repo = await AccountRepositoryImpl.load(storage);
    expect(repo.current.map((a) => a.id), ['a', 'b']);
    expect(repo.current.first.apiKey, 'ka');
  });

  test('save adds a new account, persists it and exposes an unmodifiable list', () async {
    final repo = await AccountRepositoryImpl.load(storage);
    await repo.save(_acc('a'));
    await repo.save(_acc('b'));
    expect(repo.current.map((a) => a.id), ['a', 'b']);
    expect(await _storedIds(storage), ['a', 'b']);
    expect(() => repo.current.add(_acc('c')), throwsUnsupportedError);
  });

  test('save replaces an existing account in place', () async {
    final repo = await AccountRepositoryImpl.load(storage);
    await repo.save(_acc('a'));
    await repo.save(_acc('b'));
    await repo.save(_acc('a', label: 'Renamed'));
    expect(repo.current.map((a) => a.id), ['a', 'b']);
    expect(repo.current.first.label, 'Renamed');
    final reloaded = await AccountRepositoryImpl.load(storage);
    expect(reloaded.current.first.label, 'Renamed');
  });

  test('delete removes the account and persists; unknown ids are a no-op', () async {
    final repo = await AccountRepositoryImpl.load(storage);
    await repo.save(_acc('a'));
    await repo.save(_acc('b'));
    await repo.delete('a');
    expect(repo.current.map((a) => a.id), ['b']);
    expect(await _storedIds(storage), ['b']);
    await repo.delete('zzz');
    expect(repo.current.map((a) => a.id), ['b']);
  });

  test('watch emits the current list then every change', () async {
    final repo = await AccountRepositoryImpl.load(storage);
    final emitted = <List<String>>[];
    final sub = repo.watch().listen((l) => emitted.add([for (final a in l) a.id]));
    await pumpEventQueue();
    await repo.save(_acc('a'));
    await repo.delete('a');
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted, [
      <String>[],
      ['a'],
      <String>[],
    ]);
  });
}
