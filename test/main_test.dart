import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/app.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/repositories/settings_repository.dart';
import 'package:nexora_app/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => sl.reset());

  testWidgets('main wires dependencies and runs NexoraApp', (tester) async {
    await app.main();
    await tester.pump();

    expect(sl.isRegistered<SettingsRepository>(), isTrue);
    expect(find.byType(NexoraApp), findsOneWidget);
  });
}
