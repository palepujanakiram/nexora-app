import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/execution_result.dart';
import '../../../common/domain/usecases/watch_accounts_usecase.dart';
import '../../../common/domain/usecases/watch_settings_usecase.dart';
import '../../../common/error/exceptions.dart';
import '../model/signal_state.dart';
import '../usecase/execute_signal_usecase.dart';
import '../usecase/parse_signal_usecase.dart';

class SignalViewModel extends ChangeNotifier {
  SignalViewModel(this._parse, this._execute, WatchAccountsUseCase watchAccounts, WatchSettingsUseCase watchSettings) {
    _subs = [
      watchAccounts().listen((a) => _emit(_state.copyWith(accounts: a))),
      watchSettings().listen((s) => _emit(_state.copyWith(settings: s))),
    ];
  }

  final ParseSignalUseCase _parse;
  final ExecuteSignalUseCase _execute;
  late final List<StreamSubscription<Object?>> _subs;

  late SignalState _state = SignalState(exitsSupported: _execute.placesExits);
  SignalState get state => _state;

  void parse(String text) {
    try {
      _emit(_state.copyWith(clearParse: true).copyWith(signal: _parse(text)));
    } on SignalParseException catch (e) {
      _emit(_state.copyWith(clearParse: true).copyWith(error: e.message));
    }
  }

  /// Re-parses as the user edits, once they've parsed at least once.
  void onTextChanged(String text) {
    if (_state.signal != null || _state.error != null) parse(text);
  }

  void clear() => _emit(_state.copyWith(clearParse: true));

  void setSelected(String accountId, bool selected) =>
      _emit(_state.copyWith(selectionOverrides: {..._state.selectionOverrides, accountId: selected}));

  /// Places the signal on the chosen accounts.
  Future<List<ExecutionResult>> execute() async {
    final signal = _state.signal;
    if (signal == null || !_state.canExecute) return const [];
    _emit(_state.copyWith(busy: true));
    try {
      return await _execute(signal, _state.chosen.map((a) => a.id).toSet());
    } finally {
      _emit(_state.copyWith(busy: false));
    }
  }

  void _emit(SignalState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
