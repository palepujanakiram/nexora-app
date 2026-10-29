import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/account_edit/usecase/delete_account_usecase.dart';
import '../../screens/account_edit/usecase/save_account_usecase.dart';
import '../../screens/accounts/usecase/get_login_url_usecase.dart';
import '../../screens/accounts/usecase/login_with_redirect_usecase.dart';
import '../../screens/accounts/usecase/set_access_token_usecase.dart';
import '../../screens/accounts/usecase/toggle_account_enabled_usecase.dart';
import '../../screens/activity/usecase/clear_activity_usecase.dart';
import '../../screens/activity/usecase/watch_activity_usecase.dart';
import '../../screens/login/usecase/get_sign_in_notice_usecase.dart';
import '../../screens/login/usecase/sign_in_usecase.dart';
import '../../screens/settings/usecase/change_password_usecase.dart';
import '../../screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import '../../screens/settings/usecase/get_server_ip_usecase.dart';
import '../../screens/settings/usecase/sign_out_usecase.dart';
import '../../screens/settings/usecase/test_proxy_usecase.dart';
import '../../screens/settings/usecase/update_settings_usecase.dart';
import '../../screens/settings/usecase/watch_server_usecase.dart';
import '../../screens/signal/usecase/execute_signal_usecase.dart';
import '../../screens/signal/usecase/parse_signal_usecase.dart';
import '../data/datasources/local/preferences_datasource.dart';
import '../data/datasources/local/secure_storage_datasource.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/activity_repository_impl.dart';
import '../data/repositories/broker_repository_impl.dart';
import '../data/repositories/proxy_repository_impl.dart';
import '../data/repositories/server/server_account_repository.dart';
import '../data/repositories/server/server_activity_repository.dart';
import '../data/repositories/server/server_broker_repository.dart';
import '../data/repositories/server/server_signal_execution_repository.dart';
import '../data/repositories/server_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/activity_repository.dart';
import '../domain/repositories/broker_repository.dart';
import '../domain/repositories/proxy_repository.dart';
import '../domain/repositories/server_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/signal_execution_repository.dart';
import '../domain/services/signal_parser.dart';
import '../domain/entities/server_session.dart';
import '../domain/usecases/sync_from_server_usecase.dart';
import '../domain/usecases/watch_accounts_usecase.dart';
import '../domain/usecases/watch_settings_usecase.dart';

final sl = GetIt.instance;

/// Bumped whenever the data repositories are swapped (connecting to or
/// leaving a server), so the screens rebuild their view models on the new ones.
final dataGeneration = ValueNotifier<int>(0);

/// The server session the data repositories are wired to; null while signed
/// out. The app shows the login screen until there is one.
final activeSession = ValueNotifier<ServerSession?>(null);

/// Wires data sources → repositories → use cases. View models are created
/// by their views and pull use cases from [sl].
Future<void> configureDependencies({http.Client? httpClient}) async {
  // Data sources
  final prefs = PreferencesDataSource(await SharedPreferences.getInstance());
  final secure = SecureStorageDataSource();
  final client = httpClient ?? http.Client();

  // Repositories (loaded once; they cache in memory and stream changes)
  final settings = SettingsRepositoryImpl(prefs);
  final server = await ServerRepositoryImpl.load(client, secure);
  sl
    ..registerSingleton<SettingsRepository>(settings)
    ..registerSingleton<ServerRepository>(server)
    ..registerSingleton<ProxyRepository>(ProxyRepositoryImpl(client));

  /// Accounts, broker logins, orders and activity live on the server while
  /// signed in. Signed out, the device-only repositories stand in; the login
  /// screen doesn't use them.
  var wired = false;
  Future<void> switchDataSource(ServerSession? session) async {
    if (wired && identical(session, activeSession.value)) return;
    wired = true;
    activeSession.value = session;
    for (final unregister in [
      sl.unregisterIfRegistered<AccountRepository>,
      sl.unregisterIfRegistered<ActivityRepository>,
      sl.unregisterIfRegistered<BrokerRepository>,
      sl.unregisterIfRegistered<SignalExecutionRepository>,
    ]) {
      await unregister();
    }
    if (session == null) {
      sl
        ..registerSingleton<AccountRepository>(await AccountRepositoryImpl.load(secure))
        ..registerSingleton<ActivityRepository>(ActivityRepositoryImpl(prefs))
        ..registerSingleton<BrokerRepository>(BrokerRepositoryImpl(client, settings));
    } else {
      final api = server.api(session);
      final accounts = ServerAccountRepository(api);
      sl
        ..registerSingleton<AccountRepository>(accounts)
        ..registerSingleton<ActivityRepository>(ServerActivityRepository(api))
        ..registerSingleton<BrokerRepository>(ServerBrokerRepository(api, accounts))
        ..registerSingleton<SignalExecutionRepository>(ServerSignalExecutionRepository(api));
    }
    dataGeneration.value++;
  }

  await switchDataSource(server.current);
  sl.registerSingleton<SwitchDataSource>(switchDataSource);
  // The server ended the session (expired, or the password changed elsewhere).
  server.watch().listen((s) {
    if (s == null) unawaited(switchDataSource(null));
  });

  // Shared use cases
  sl
    ..registerFactory(() => WatchAccountsUseCase(sl()))
    ..registerFactory(() => WatchSettingsUseCase(sl()))
    ..registerFactory(() => SyncFromServerUseCase([sl<AccountRepository>(), sl<ActivityRepository>()]));

  // Login screen
  sl
    ..registerFactory(() => SignInUseCase(sl(), sl()))
    ..registerFactory(() => GetSignInNoticeUseCase(sl()));

  // Signal screen
  sl
    ..registerFactory(() => ParseSignalUseCase(SignalParser()))
    ..registerFactory(() => ExecuteSignalUseCase(sl(), sl(), sl(), sl(),
        remote: sl.isRegistered<SignalExecutionRepository>() ? sl<SignalExecutionRepository>() : null));

  // Accounts screen
  sl
    ..registerFactory(() => ToggleAccountEnabledUseCase(sl()))
    ..registerFactory(() => GetLoginUrlUseCase(sl()))
    ..registerFactory(() => LoginWithRedirectUseCase(sl(), sl()))
    ..registerFactory(() => SetAccessTokenUseCase(sl()));

  // Account edit screen
  sl
    ..registerFactory(() => SaveAccountUseCase(sl()))
    ..registerFactory(() => DeleteAccountUseCase(sl()));

  // Activity screen
  sl
    ..registerFactory(() => WatchActivityUseCase(sl()))
    ..registerFactory(() => ClearActivityUseCase(sl()));

  // Settings screen
  sl
    ..registerFactory(() => UpdateSettingsUseCase(sl()))
    ..registerFactory(() => GetProxyWorkerScriptUseCase(sl()))
    ..registerFactory(() => TestProxyUseCase(sl()))
    ..registerFactory(() => WatchServerUseCase(sl()))
    ..registerFactory(() => SignOutUseCase(sl(), sl()))
    ..registerFactory(() => ChangePasswordUseCase(sl(), sl()))
    ..registerFactory(() => GetServerIpUseCase(sl()));
}

extension on GetIt {
  Future<void> unregisterIfRegistered<T extends Object>() async {
    if (isRegistered<T>()) await unregister<T>();
  }
}
