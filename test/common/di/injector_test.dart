import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/repositories/account_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/activity_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/broker_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/proxy_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/settings_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/repositories/server/server_account_repository.dart';
import 'package:nexora_app/common/data/repositories/server/server_activity_repository.dart';
import 'package:nexora_app/common/data/repositories/server/server_broker_repository.dart';
import 'package:nexora_app/common/data/repositories/server/server_signal_execution_repository.dart';
import 'package:nexora_app/common/data/repositories/server_repository_impl.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/common/domain/repositories/server_repository.dart';
import 'package:nexora_app/common/domain/repositories/signal_execution_repository.dart';
import 'package:nexora_app/common/domain/usecases/sync_from_server_usecase.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/send_code_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/repositories/account_repository.dart';
import 'package:nexora_app/common/domain/repositories/activity_repository.dart';
import 'package:nexora_app/common/domain/repositories/broker_repository.dart';
import 'package:nexora_app/common/domain/repositories/proxy_repository.dart';
import 'package:nexora_app/common/domain/repositories/settings_repository.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/delete_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/save_account_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/login_with_redirect_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/set_access_token_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/toggle_account_enabled_usecase.dart';
import 'package:nexora_app/screens/activity/usecase/clear_activity_usecase.dart';
import 'package:nexora_app/screens/activity/usecase/watch_activity_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/test_proxy_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/update_settings_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/execute_signal_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/parse_signal_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({'app_settings_v1': '{"themeColor":"indigo"}'});
    FlutterSecureStorage.setMockInitialValues({
      'broker_accounts_v1':
          '[{"id":"a1","broker":"upstox","label":"Mine","apiKey":"k","apiSecret":"s"}]',
    });
  });

  tearDown(() => sl.reset());

  test('registers repository singletons backed by stored data', () async {
    await configureDependencies();

    expect(sl<SettingsRepository>(), isA<SettingsRepositoryImpl>());
    expect(sl<AccountRepository>(), isA<AccountRepositoryImpl>());
    expect(sl<ActivityRepository>(), isA<ActivityRepositoryImpl>());
    expect(sl<BrokerRepository>(), isA<BrokerRepositoryImpl>());
    expect(sl<ProxyRepository>(), isA<ProxyRepositoryImpl>());
    expect(identical(sl<SettingsRepository>(), sl<SettingsRepository>()), isTrue);

    expect(sl<SettingsRepository>().current.themeColor, ThemeColor.indigo);
    expect(sl<AccountRepository>().current.single.label, 'Mine');
    expect(sl<ActivityRepository>().current, isEmpty);
  });

  test('every use case resolves as a new instance per lookup', () async {
    await configureDependencies();

    final resolvers = <Object Function()>[
      () => sl<WatchAccountsUseCase>(),
      () => sl<WatchSettingsUseCase>(),
      () => sl<ParseSignalUseCase>(),
      () => sl<ExecuteSignalUseCase>(),
      () => sl<ToggleAccountEnabledUseCase>(),
      () => sl<GetLoginUrlUseCase>(),
      () => sl<LoginWithRedirectUseCase>(),
      () => sl<SetAccessTokenUseCase>(),
      () => sl<SaveAccountUseCase>(),
      () => sl<DeleteAccountUseCase>(),
      () => sl<WatchActivityUseCase>(),
      () => sl<ClearActivityUseCase>(),
      () => sl<UpdateSettingsUseCase>(),
      () => sl<GetProxyWorkerScriptUseCase>(),
      () => sl<TestProxyUseCase>(),
      () => sl<SyncFromServerUseCase>(),
      () => sl<WatchServerUseCase>(),
      () => sl<SignInUseCase>(),
      () => sl<GetSignInNoticeUseCase>(),
      () => sl<SignOutUseCase>(),
      () => sl<SendCodeUseCase>(),
      () => sl<GetServerIpUseCase>(),
    ];
    for (final resolve in resolvers) {
      final a = resolve();
      expect(identical(a, resolve()), isFalse, reason: '${a.runtimeType} is a factory');
    }
  });

  test('watch settings use case is wired to the settings repository', () async {
    await configureDependencies();
    final first = await sl<WatchSettingsUseCase>()().first;
    expect(first.themeColor, ThemeColor.indigo);
  });

  test('calling it twice without a reset fails (singletons are registered once)', () async {
    await configureDependencies();
    await expectLater(configureDependencies(), throwsA(anything));
  });

  test('without a server, nothing is placed remotely', () async {
    await configureDependencies();
    expect(sl<ServerRepository>(), isA<ServerRepositoryImpl>());
    expect(sl<ServerRepository>().current, isNull);
    expect(activeSession.value, isNull);
    expect(sl.isRegistered<SignalExecutionRepository>(), isFalse);
    expect(sl<ExecuteSignalUseCase>().remote, isNull);
  });

  test('a saved server session puts accounts, logins, orders and activity on the server', () async {
    FlutterSecureStorage.setMockInitialValues({
      'server_session_v3': '{"url":"https://srv.test","token":"tok","refreshToken":"rt","phone":"+919876543210"}',
      'broker_accounts_v1': '[{"id":"a1","broker":"upstox","label":"Mine","apiKey":"k","apiSecret":"s"}]',
    });
    final client = MockClient((_) async => http.Response('{"accounts":[]}', 200));
    final generation = dataGeneration.value;
    await configureDependencies(httpClient: client);

    expect(sl<ServerRepository>().current?.phone, '+919876543210');
    expect(activeSession.value, same(sl<ServerRepository>().current));
    expect(sl<AccountRepository>(), isA<ServerAccountRepository>());
    expect(sl<ActivityRepository>(), isA<ServerActivityRepository>());
    expect(sl<BrokerRepository>(), isA<ServerBrokerRepository>());
    expect(sl<SignalExecutionRepository>(), isA<ServerSignalExecutionRepository>());
    expect(sl<ExecuteSignalUseCase>().remote, isNotNull);
    expect(dataGeneration.value, generation + 1);

    // Leaving the server brings back what's stored on this device.
    await sl<SwitchDataSource>()(null);
    expect(sl<AccountRepository>(), isA<AccountRepositoryImpl>());
    expect(sl<AccountRepository>().current.single.label, 'Mine');
    expect(sl.isRegistered<SignalExecutionRepository>(), isFalse);
    expect(dataGeneration.value, generation + 2);
    expect(activeSession.value, isNull);

    // Switching to the session already wired changes nothing.
    await sl<SwitchDataSource>()(null);
    expect(dataGeneration.value, generation + 2);

    await sl<SwitchDataSource>()(const ServerSession(url: 'https://srv.test', token: 't', phone: '+919876543210'));
    expect(sl<AccountRepository>(), isA<ServerAccountRepository>());
  });

  test('when the server rejects the token, the app is signed out', () async {
    FlutterSecureStorage.setMockInitialValues({
      'server_session_v3': '{"url":"https://srv.test","token":"tok","refreshToken":"rt","phone":"+919876543210"}',
    });
    final client = MockClient((_) async => http.Response('{"error":{"code":"unauthorized","message":"x"}}', 401));
    await configureDependencies(httpClient: client);
    expect(activeSession.value, isNotNull);

    await expectLater((sl<AccountRepository>() as ServerAccountRepository).refresh(), throwsA(anything));
    await pumpEventQueue();
    expect(sl<ServerRepository>().current, isNull);
    expect(activeSession.value, isNull);
    expect(sl<AccountRepository>(), isA<AccountRepositoryImpl>());
    expect(sl<ServerRepository>().endedReason, 'Your session ended. Sign in again.');
  });
}
