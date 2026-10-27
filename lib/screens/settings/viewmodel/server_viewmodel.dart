import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/server_session.dart';
import '../model/server_state.dart';
import '../usecase/connect_server_usecase.dart';
import '../usecase/disconnect_server_usecase.dart';
import '../usecase/get_server_ip_usecase.dart';
import '../usecase/watch_server_usecase.dart';

/// Connecting this device to a nexora-backend server, from Settings.
class ServerViewModel extends ChangeNotifier {
  ServerViewModel(WatchServerUseCase watch, this._connect, this._disconnect, this._serverIp) {
    _sub = watch().listen((s) => _emit(
          s == null ? _state.copyWith(clearSession: true, clearServerIp: true) : _state.copyWith(session: s),
        ));
  }

  final ConnectServerUseCase _connect;
  final DisconnectServerUseCase _disconnect;
  final GetServerIpUseCase _serverIp;
  late final StreamSubscription<ServerSession?> _sub;

  ServerState _state = const ServerState();
  ServerState get state => _state;

  /// Signs in, or creates a login when [inviteCode] is given. Returns true on success.
  Future<bool> connect({required String url, required String email, required String password, String? inviteCode}) =>
      _run(() => _connect(url: url, email: email, password: password, inviteCode: inviteCode));

  Future<bool> disconnect() => _run(_disconnect.call);

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
