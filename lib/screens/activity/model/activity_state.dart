import '../../../common/domain/entities/execution_result.dart';

class ActivityState {
  const ActivityState({this.results = const []});

  /// Newest first.
  final List<ExecutionResult> results;

  bool get isEmpty => results.isEmpty;
}
