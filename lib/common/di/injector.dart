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
import '../../screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import '../../screens/settings/usecase/test_proxy_usecase.dart';
import '../../screens/settings/usecase/update_settings_usecase.dart';
import '../../screens/signal/usecase/execute_signal_usecase.dart';
import '../../screens/signal/usecase/parse_signal_usecase.dart';
import '../data/datasources/local/preferences_datasource.dart';
import '../data/datasources/local/secure_storage_datasource.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/activity_repository_impl.dart';
import '../data/repositories/broker_repository_impl.dart';
import '../data/repositories/proxy_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/activity_repository.dart';
import '../domain/repositories/broker_repository.dart';
import '../domain/repositories/proxy_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/signal_parser.dart';
import '../domain/usecases/watch_accounts_usecase.dart';
import '../domain/usecases/watch_settings_usecase.dart';

final sl = GetIt.instance;

/// Wires data sources → repositories → use cases. View models are created
/// by their views and pull use cases from [sl].
Future<void> configureDependencies() async {
  // Data sources
  final prefs = PreferencesDataSource(await SharedPreferences.getInstance());
  final secure = SecureStorageDataSource();

  // Repositories (loaded once; they cache in memory and stream changes)
  final settings = SettingsRepositoryImpl(prefs);
  final httpClient = http.Client();
  sl
    ..registerSingleton<SettingsRepository>(settings)
    ..registerSingleton<AccountRepository>(await AccountRepositoryImpl.load(secure))
    ..registerSingleton<ActivityRepository>(ActivityRepositoryImpl(prefs))
    ..registerSingleton<BrokerRepository>(BrokerRepositoryImpl(httpClient, settings))
    ..registerSingleton<ProxyRepository>(ProxyRepositoryImpl(httpClient));

  // Shared use cases
  sl
    ..registerFactory(() => WatchAccountsUseCase(sl()))
    ..registerFactory(() => WatchSettingsUseCase(sl()));

  // Signal screen
  sl
    ..registerFactory(() => ParseSignalUseCase(SignalParser()))
    ..registerFactory(() => ExecuteSignalUseCase(sl(), sl(), sl(), sl()));

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
    ..registerFactory(() => TestProxyUseCase(sl()));
}
