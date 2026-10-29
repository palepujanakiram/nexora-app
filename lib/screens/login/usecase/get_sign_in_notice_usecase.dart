import '../../../common/domain/repositories/server_repository.dart';

/// Why the user is back on the login screen without having signed out
/// (e.g. the session expired), or null.
class GetSignInNoticeUseCase {
  const GetSignInNoticeUseCase(this._server);

  final ServerRepository _server;

  String? call() => _server.endedReason;
}
