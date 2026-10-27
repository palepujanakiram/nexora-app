import '../entities/execution_result.dart';

abstract interface class ActivityRepository {
  List<ExecutionResult> get current;

  /// Emits the activity log (newest first), then every change.
  Stream<List<ExecutionResult>> watch();

  /// Prepends [results] to the log.
  Future<void> addAll(List<ExecutionResult> results);

  Future<void> clear();
}
