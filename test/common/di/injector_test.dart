import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/repositories/account_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/activity_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/broker_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/proxy_repository_impl.dart';
import 'package:nexora_app/common/data/repositories/settings_repository_impl.dart';
import 'package:nexora_app/common/di/injector.dart';
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
}
