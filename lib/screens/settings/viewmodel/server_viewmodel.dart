import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/server_session.dart';
import '../model/server_state.dart';
import '../usecase/get_server_ip_usecase.dart';
import '../usecase/sign_out_usecase.dart';
import '../usecase/watch_server_usecase.dart';

/// Settings → Server: who's signed in, the server's IP, and sign-out.
class ServerViewModel extends ChangeNotifier {
  ServerViewModel(WatchServerUseCase watch, this._signOut, this._serverIp) {
    _sub = watch().listen((s) => _emit(
          s == null ? _state.copyWith(clearSession: true, clearServerIp: true) : _state.copyWith(session: s),
        ));
  }

  final SignOutUseCase _signOut;
  final GetServerIpUseCase _serverIp;
  late final StreamSubscription<ServerSession?> _sub;

  ServerState _state = const ServerState();
  ServerState get state => _state;

  Future<bool> signOut() => _run(_signOut.call);

  Future<void> loadServerIp() async {
    _emit(_state.copyWith(loadingIp: true, clearError: true));
    try {
      _emit(_state.copyWith(loadingIp: false, serverIp: await _serverIp()));
    } catch (e) {
      _emit(_state.copyWith(loadingIp: false, error: e.toString()));
    }
  }

  void clearError() => _emit(_state.copyWith(clearError: true));

  Future<bool> _run(Future<void> Function() action) async {
    if (_state.busy) return false;
    _emit(_state.copyWith(busy: true, clearError: true));
    try {
      await action();
      _emit(_state.copyWith(busy: false));
      return true;
    } catch (e) {
      _emit(_state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  bool _disposed = false;

  void _emit(ServerState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}
