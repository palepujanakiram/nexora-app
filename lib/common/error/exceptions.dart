/// Thrown when free-text cannot be parsed into a trade signal.
class SignalParseException implements Exception {
  SignalParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown for broker API failures (HTTP errors, rejected orders, bad tokens).
class BrokerApiException implements Exception {
  BrokerApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the nexora-backend server refuses a request or can't be reached.
class ServerApiException implements Exception {
  ServerApiException(this.message, {this.statusCode, this.code});
  final String message;

  /// HTTP status, or null when the server couldn't be reached.
  final int? statusCode;

  /// The server's error code, e.g. `unauthorized` or `broker_error`.
  final String? code;

  @override
  String toString() => message;
}
