import '../repositories/refreshable.dart';

/// Fetches accounts and activity again from the server, to pick up changes
/// made on other devices. Does nothing when the app works on its own.
class SyncFromServerUseCase {
  const SyncFromServerUseCase(this._repositories);

  final List<Object> _repositories;

  /// Returns why it failed, or null.
  Future<String?> call() async {
    try {
      await Future.wait(_repositories.whereType<Refreshable>().map((r) => r.refresh()));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
