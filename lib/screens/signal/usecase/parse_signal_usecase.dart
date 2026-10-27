import '../../../common/domain/entities/trade_signal.dart';
import '../../../common/domain/services/signal_parser.dart';

/// Throws [SignalParseException] when the text is not a valid signal.
class ParseSignalUseCase {
  const ParseSignalUseCase(this._parser);

  final SignalParser _parser;

  TradeSignal call(String text) => _parser.parse(text);
}
