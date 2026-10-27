import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/usecases/watch_accounts_usecase.dart';
import '../model/accounts_state.dart';
import '../usecase/toggle_account_enabled_usecase.dart';

class AccountsViewModel extends ChangeNotifier {
  AccountsViewModel(WatchAccountsUseCase watchAccounts, this._toggleEnabled) {
    _sub = watchAccounts().listen((accounts) {
      _state = AccountsState(accounts: accounts);
      notifyListeners();
    });
  }

  final ToggleAccountEnabledUseCase _toggleEnabled;
  late final StreamSubscription<List<BrokerAccount>> _sub;

  AccountsState _state = const AccountsState();
  AccountsState get state => _state;

  Future<void> setEnabled(BrokerAccount account, bool enabled) => _toggleEnabled(account, enabled);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
