import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/delete_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/save_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/view/account_edit_view.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/login_with_redirect_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/set_access_token_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/toggle_account_enabled_usecase.dart';
import 'package:nexora_app/screens/accounts/view/accounts_view.dart';
import 'package:nexora_app/screens/accounts/view/widgets/account_tile.dart';
import 'package:nexora_app/screens/accounts/view/widgets/login_dialog.dart';

import '../../../fakes.dart';

void main() {
  late FakeAccountRepository accounts;

  Future<void> register(List<BrokerAccount> initial) async {
    accounts = FakeAccountRepository(initial);
    final broker = FakeBrokerRepository();
    await sl.reset();
    sl
      ..registerFactory(() => WatchAccountsUseCase(accounts))
      ..registerFactory(() => ToggleAccountEnabledUseCase(accounts))
      ..registerFactory(() => GetLoginUrlUseCase(broker))
      ..registerFactory(() => LoginWithRedirectUseCase(broker, accounts))
      ..registerFactory(() => SetAccessTokenUseCase(accounts))
      ..registerFactory(() => SaveAccountUseCase(accounts))
      ..registerFactory(() => DeleteAccountUseCase(accounts));
  }

  setUp(() => register(const []));

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AccountsView()));
    await tester.pumpAndSettle();
  }

  testWidgets('empty state', (tester) async {
    await pumpView(tester);

    expect(find.text('Broker accounts'), findsOneWidget);
    expect(find.text('No accounts yet.'), findsOneWidget);
    expect(find.byType(AccountTile), findsNothing);
    expect(find.text('Add account'), findsOneWidget);
  });

  testWidgets('lists accounts grouped by broker and reacts to changes', (tester) async {
    await register([
      testAccount(id: 'z'),
      testAccount(id: 'u').copyWith(broker: BrokerType.upstox),
    ]);
    await pumpView(tester);

    expect(find.text('No accounts yet.'), findsNothing);
    expect(find.text('Zerodha (Kite Connect)'), findsOneWidget);
    expect(find.text('Upstox'), findsOneWidget);
    expect(find.byType(AccountTile), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Zerodha (Kite Connect)')).dy,
      lessThan(tester.getTopLeft(find.text('Upstox')).dy),
    );

    await accounts.delete('u');
    await tester.pumpAndSettle();
    expect(find.text('Upstox'), findsNothing);
    expect(find.byType(AccountTile), findsOneWidget);
  });

  testWidgets('toggling "Use by default" saves the account', (tester) async {
    await register([testAccount(enabled: true)]);
    await pumpView(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(accounts.current.single.enabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('tapping an account opens the editor for it', (tester) async {
    await register([testAccount()]);
    await pumpView(tester);

    await tester.tap(find.text('Test a'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountEditView), findsOneWidget);
    expect(tester.widget<AccountEditView>(find.byType(AccountEditView)).account?.id, 'a');
    expect(find.text('Edit account'), findsOneWidget);
  });

  testWidgets('Add account opens an empty editor', (tester) async {
    await pumpView(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(AccountEditView), findsOneWidget);
    expect(tester.widget<AccountEditView>(find.byType(AccountEditView)).account, isNull);
  });

  testWidgets('Login opens the login dialog for the account', (tester) async {
    await register([testAccount(loggedIn: false)]);
    await pumpView(tester);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginDialog), findsOneWidget);
    expect(find.text('Log in — Test a'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tok');
    await tester.tap(find.text('It is an access token'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginDialog), findsNothing);
    expect(find.text('Re-login'), findsOneWidget);
    expect(find.text('Logged in'), findsOneWidget);
  });
}
