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
