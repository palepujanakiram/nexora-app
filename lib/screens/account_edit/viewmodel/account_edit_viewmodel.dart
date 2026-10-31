import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/broker_account.dart';
import '../model/account_form.dart';
import '../usecase/delete_account_usecase.dart';
import '../usecase/get_broker_callback_url_usecase.dart';
import '../usecase/save_account_usecase.dart';

class AccountEditViewModel extends ChangeNotifier {
  AccountEditViewModel(this.existing, this._save, this._delete, [this._callbackUrl])
      : _form = AccountForm.fromAccount(existing) {
    _form = _withCallback(_form);
  }

  final BrokerAccount? existing;
  final SaveAccountUseCase _save;
  final DeleteAccountUseCase _delete;
  final GetBrokerCallbackUrlUseCase? _callbackUrl;

  /// The server's login callback for the chosen broker: the redirect URL to
  /// register in the broker's app. Null when not signed in to a server.
  String? get callbackUrl => _callbackUrl?.call(_form.broker);

  AccountForm _form;
  AccountForm get form => _form;

  bool get isNew => existing == null;

  /// On a server the secret isn't sent back to the app: the field starts
  /// empty, and leaving it empty keeps the stored one.
  bool get keepsStoredSecret => existing != null && existing!.apiSecret.isEmpty;

  bool _showSecret = false;
  bool get showSecret => _showSecret;

  void update(AccountForm Function(AccountForm) change) {
    final next = change(_form);
    // Fill in the server's callback when a broker that needs a redirect URI
    // is picked, not as the user edits the field.
    _form = next.broker == _form.broker ? next : _withCallback(next);
    notifyListeners();
  }

  /// A new account's empty redirect URI starts as the server's callback.
  AccountForm _withCallback(AccountForm f) {
    if (!isNew || !f.needsRedirectUri || f.redirectUri.isNotEmpty) return f;
    final url = _callbackUrl?.call(f.broker);
    return url == null ? f : f.copyWith(redirectUri: url);
  }

  void toggleShowSecret() {
    _showSecret = !_showSecret;
    notifyListeners();
  }

  /// Call only after the view's form validators pass.
  Future<void> save() => _save(_form, existing: existing);

  Future<void> delete() => _delete(existing!.id);
}
