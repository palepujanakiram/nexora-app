import '../repositories/refreshable.dart';

/// Fetches accounts and activity again from the server, to pick up changes
/// made on other devices. Does nothing when the app works on its own.
///
/// One after the other, in order: the activity log names accounts, so the
/// accounts come first.
class SyncFromServerUseCase {
  const SyncFromServerUseCase(this._repositories);

  final List<Object> _repositories;

  /// Returns why it failed, or null.
  Future<String?> call() async {
    try {
      for (final r in _repositories.whereType<Refreshable>()) {
        await r.refresh();
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
