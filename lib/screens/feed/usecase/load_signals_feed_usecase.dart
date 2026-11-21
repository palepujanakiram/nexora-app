import '../../../common/domain/entities/eps_signal.dart';
import '../../../common/domain/repositories/eps_signals_repository.dart';

class LoadSignalsFeedUseCase {
  const LoadSignalsFeedUseCase(this._signals);

  final EpsSignalsRepository _signals;

  Future<EpsFeed> call() => _signals.fetchSignals();
}
