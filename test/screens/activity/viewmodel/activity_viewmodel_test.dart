import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/screens/activity/usecase/clear_activity_usecase.dart';
import 'package:nexora_app/screens/activity/usecase/watch_activity_usecase.dart';
import 'package:nexora_app/screens/activity/viewmodel/activity_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  test('mirrors the activity stream, clears, and stops after dispose', () async {
    final repo = FakeActivityRepository();
    final vm = ActivityViewModel(WatchActivityUseCase(repo), ClearActivityUseCase(repo));
    var notified = 0;
    vm.addListener(() => notified++);
    expect(vm.state.isEmpty, isTrue);

    final r = ExecutionResult(accountLabel: 'a', broker: 'b', signalText: 's', paper: true, time: DateTime(2026));
    await repo.addAll([r]);
    await pumpEventQueue();
    expect(vm.state.results.single, same(r));
    expect(notified, greaterThan(0));

    await vm.clear();
    await pumpEventQueue();
    expect(vm.state.isEmpty, isTrue);
    expect(repo.current, isEmpty);

    vm.dispose();
    final before = notified;
    await repo.addAll([r]);
    await pumpEventQueue();
    expect(notified, before);
  });
}
