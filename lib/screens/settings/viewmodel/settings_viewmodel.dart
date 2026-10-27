import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/domain/entities/app_settings.dart';
import '../../../common/domain/usecases/watch_settings_usecase.dart';
import '../model/settings_state.dart';
import '../usecase/get_proxy_worker_script_usecase.dart';
import '../usecase/test_proxy_usecase.dart';
import '../usecase/update_settings_usecase.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(WatchSettingsUseCase watchSettings, this._update, this._workerScript, this._testProxy) {
    _sub = watchSettings().listen((s) => _emit(_state.copyWith(settings: s)));
  }

  final UpdateSettingsUseCase _update;
  final GetProxyWorkerScriptUseCase _workerScript;
  final TestProxyUseCase _testProxy;
  late final StreamSubscription<AppSettings> _sub;

  SettingsState _state = const SettingsState(isWeb: kIsWeb);
  SettingsState get state => _state;

  Future<void> setThemeColor(ThemeColor c) => _update((s) => s.copyWith(themeColor: c));

  Future<void> setEntryPriceMode(EntryPriceMode m) => _update((s) => s.copyWith(entryPriceMode: m));

  Future<void> setExitMode(ExitMode m) => _update((s) => s.copyWith(exitMode: m));

  Future<void> setTargetIndex(int i) => _update((s) => s.copyWith(targetIndex: i));

  Future<void> setCorsProxy(String url) {
    final trimmed = url.trim();
    if (trimmed == _state.settings.corsProxy) return Future.value();
    _emit(_state.copyWith(clearProxyHealth: true));
    return _update((s) => s.copyWith(corsProxy: trimmed));
  }

  /// Saves [url] and checks it against the proxy's /health endpoint.
  Future<void> testProxy(String url) async {
    await setCorsProxy(url);
    _emit(_state.copyWith(testingProxy: true, clearProxyHealth: true));
    final health = await _testProxy(url);
    _emit(_state.copyWith(testingProxy: false, proxyHealth: health));
  }

  Future<String> workerScript() => _workerScript();

  void _emit(SettingsState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
