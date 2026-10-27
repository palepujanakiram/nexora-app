import 'package:intl/intl.dart';

enum TradeAction { buy, sell }

enum OptionType { call, put }

/// Underlyings whose options trade on BSE (BFO segment). Everything else is
/// assumed to be NSE F&O (NFO).
const bseUnderlyings = {'SENSEX', 'BANKEX', 'SENSEX50'};

/// A parsed option-trading signal, e.g.
/// `BUY SENSEX 29 OCT 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600`.
class TradeSignal {
  const TradeSignal({
    required this.action,
    required this.underlying,
    required this.expiry,
    required this.strike,
    required this.optionType,
    required this.entryLow,
    required this.entryHigh,
    required this.stopLoss,
    required this.targets,
    required this.raw,
    this.warnings = const [],
  });

  final TradeAction action;
  final String underlying;
  final DateTime expiry;
  final double strike;
  final OptionType optionType;
  final double entryLow;
  final double entryHigh;
  final double? stopLoss;
  final List<double> targets;
  final String raw;
  final List<String> warnings;

  bool get isBuy => action == TradeAction.buy;
  String get side => isBuy ? 'BUY' : 'SELL';
  String get exitSide => isBuy ? 'SELL' : 'BUY';
  String get optionCode => optionType == OptionType.call ? 'CE' : 'PE';
  String get exchange => bseUnderlyings.contains(underlying) ? 'BFO' : 'NFO';
  String get expiryIso => DateFormat('yyyy-MM-dd').format(expiry);

  String get contractLabel =>
      '$underlying ${DateFormat('dd MMM yyyy').format(expiry).toUpperCase()} '
      '${_fmt(strike)} $optionCode';

  String get entryLabel =>
      entryLow == entryHigh ? _fmt(entryLow) : '${_fmt(entryLow)}–${_fmt(entryHigh)}';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
