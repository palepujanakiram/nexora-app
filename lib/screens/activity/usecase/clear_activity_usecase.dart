import '../../../common/domain/repositories/activity_repository.dart';

class ClearActivityUseCase {
  const ClearActivityUseCase(this._activity);

  final ActivityRepository _activity;

  Future<void> call() => _activity.clear();
}
