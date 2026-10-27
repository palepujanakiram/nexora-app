import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/home_tab.dart';

class HomeViewModel extends ChangeNotifier {
  /// [sync] fetches accounts and activity from the server again (when
  /// connected to one) and returns why it failed, or null.
  HomeViewModel({this._sync}) {
    unawaited(sync());
  }

  final Future<String?> Function()? _sync;

  HomeTab _tab = HomeTab.signal;
  HomeTab get tab => _tab;

  String? _syncError;

  /// Why the last fetch from the server failed; null when it worked.
  String? get syncError => _syncError;

  bool _syncing = false;
  bool _disposed = false;

  void select(HomeTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
    // Pick up what other devices changed.
    if (tab == HomeTab.accounts || tab == HomeTab.activity) unawaited(sync());
  }

  Future<void> sync() async {
    final run = _sync;
    if (run == null || _syncing) return;
    _syncing = true;
    final error = await run();
    _syncing = false;
    if (_disposed || error == _syncError) return;
    _syncError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
