import '../../../common/domain/entities/execution_result.dart';
import '../../../common/domain/repositories/activity_repository.dart';

class WatchActivityUseCase {
  const WatchActivityUseCase(this._activity);

  final ActivityRepository _activity;

  Stream<List<ExecutionResult>> call() => _activity.watch();
}
