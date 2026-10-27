import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/broker_account.dart';
import '../model/account_form.dart';
import '../usecase/delete_account_usecase.dart';
import '../usecase/save_account_usecase.dart';

class AccountEditViewModel extends ChangeNotifier {
  AccountEditViewModel(this.existing, this._save, this._delete) : _form = AccountForm.fromAccount(existing);

  final BrokerAccount? existing;
  final SaveAccountUseCase _save;
  final DeleteAccountUseCase _delete;

  AccountForm _form;
  AccountForm get form => _form;

  bool get isNew => existing == null;

  /// On a server the secret isn't sent back to the app: the field starts
  /// empty, and leaving it empty keeps the stored one.
  bool get keepsStoredSecret => existing != null && existing!.apiSecret.isEmpty;

  bool _showSecret = false;
  bool get showSecret => _showSecret;

  void update(AccountForm Function(AccountForm) change) {
    _form = change(_form);
    notifyListeners();
  }

  void toggleShowSecret() {
    _showSecret = !_showSecret;
    notifyListeners();
  }

  /// Call only after the view's form validators pass.
  Future<void> save() => _save(_form, existing: existing);

  Future<void> delete() => _delete(existing!.id);
}
