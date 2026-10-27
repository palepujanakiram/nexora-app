import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/account_edit/usecase/delete_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/save_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/viewmodel/account_edit_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeAccountRepository repo;

  AccountEditViewModel build([BrokerAccount? existing]) =>
      AccountEditViewModel(existing, SaveAccountUseCase(repo), DeleteAccountUseCase(repo));

  setUp(() => repo = FakeAccountRepository([testAccount(), testAccount(id: 'b')]));

  test('new account starts from the default form', () {
    final vm = build();
    expect(vm.isNew, isTrue);
    expect(vm.existing, isNull);
    expect(vm.form.label, '');
    expect(vm.form.paperMode, isTrue);
    expect(vm.showSecret, isFalse);
  });

  test('editing starts from the account', () {
    final vm = build(repo.current.first);
    expect(vm.isNew, isFalse);
    expect(vm.form.label, 'Test a');
    expect(vm.form.lots, '2');
    expect(vm.form.paperMode, isFalse);
  });

  test('update and toggleShowSecret notify', () {
    final vm = build();
    var notified = 0;
    vm.addListener(() => notified++);
    vm.update((f) => f.copyWith(label: 'X', broker: BrokerType.upstox));
    expect(vm.form.label, 'X');
    expect(vm.form.needsRedirectUri, isTrue);
    vm.toggleShowSecret();
    expect(vm.showSecret, isTrue);
    vm.toggleShowSecret();
    expect(vm.showSecret, isFalse);
    expect(notified, 3);
  });

  test('save creates a new account', () async {
    final vm = build()
      ..update((f) => f.copyWith(label: 'New', apiKey: 'nk', apiSecret: 'ns', lots: '4'));
    await vm.save();
    final saved = repo.current.firstWhere((a) => a.label == 'New');
    expect(saved.apiKey, 'nk');
    expect(saved.lots, 4);
    expect(repo.current, hasLength(3));
  });

  test('save updates the existing account in place', () async {
    final vm = build(repo.current.first)..update((f) => f.copyWith(label: 'Renamed'));
    await vm.save();
    expect(repo.current, hasLength(2));
    expect(repo.current.firstWhere((a) => a.id == 'a').label, 'Renamed');
  });

  test('delete removes the existing account', () async {
    await build(repo.current.first).delete();
    expect(repo.current.map((a) => a.id), ['b']);
  });
}
