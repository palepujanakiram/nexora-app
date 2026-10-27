import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/screens/activity/model/activity_state.dart';

void main() {
  test('isEmpty reflects the results', () {
    expect(const ActivityState().isEmpty, isTrue);
    final r = ExecutionResult(accountLabel: 'a', broker: 'b', signalText: 's', paper: true, time: DateTime(2026));
    final s = ActivityState(results: [r]);
    expect(s.isEmpty, isFalse);
    expect(s.results.single, same(r));
  });
}
