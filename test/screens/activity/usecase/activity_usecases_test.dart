import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/screens/activity/usecase/clear_activity_usecase.dart';
import 'package:nexora_app/screens/activity/usecase/watch_activity_usecase.dart';

import '../../../fakes.dart';

void main() {
  final r = ExecutionResult(accountLabel: 'a', broker: 'b', signalText: 's', paper: true, time: DateTime(2026));

  test('WatchActivityUseCase streams the activity log', () async {
    final repo = FakeActivityRepository();
    final seen = <int>[];
    final sub = WatchActivityUseCase(repo)().listen((l) => seen.add(l.length));
    await pumpEventQueue();
    await repo.addAll([r]);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen.last, 1);
  });

  test('ClearActivityUseCase empties the log', () async {
    final repo = FakeActivityRepository();
    await repo.addAll([r, r]);
    await ClearActivityUseCase(repo)();
    expect(repo.current, isEmpty);
  });
}
