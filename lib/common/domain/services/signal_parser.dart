import '../../error/exceptions.dart';
import '../entities/trade_signal.dart';

/// Parses free-text option signals such as:
///
///   BUY SENSEX 29 OCT 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600
///   SELL NIFTY 30-OCT-2026 24500 CE @ 120 TO 125 SL 160 TARGET 90/70
///
/// When the year is omitted, the next occurrence of that day/month (today
/// included) is used.
class SignalParser {
  SignalParser({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const _months = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  static const _num = r'(\d+(?:\.\d+)?)';

  static final _head = RegExp(
    r'\b(BUY|SELL)\s+([A-Z][A-Z0-9&]*)\s+'
    r'(\d{1,2})(?:ST|ND|RD|TH)?[\s\-/]*'
    r'(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?'
    r'(?:[\s\-/]*(\d{4}|\d{2}))?\s+'
    '$_num\\s*(CE|PE|CALL|PUT)\\b',
  );

  static final _entry = RegExp(
    r'^\s*(?:(?:AT|@|ABOVE|NEAR|AROUND|BETWEEN|RANGE|CMP)\s*:?\s*)?'
    '$_num(?:\\s*(?:-|TO|/|AND)\\s*$_num)?',
  );

  static final _sl = RegExp(
    r'\b(?:SL|STOP\s*LOSS|STOPLOSS)\s*(?:OF|IS|AT|:|-|@|=)?\s*:?\s*' + _num,
  );

  static final _targetKeyword = RegExp(r'\b(?:TGT|TARGETS?|TP)');
  static final _targetLabel =
      RegExp(r'\b(?:TGT|TARGETS?|TP)\s*(?:\d{1,2}\s*[:=\-)]|\d{1,2}\b(?=\s))?');
  static final _slTail = RegExp(r'\b(?:SL|STOP\s*LOSS|STOPLOSS)\b.*$');
  static final _numbers = RegExp(_num);

  TradeSignal parse(String input) {
    final text = input.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) throw SignalParseException('Signal is empty.');

    final head = _head.firstMatch(text);
    if (head == null) {
      throw SignalParseException(
        'Could not find "<BUY|SELL> <SYMBOL> <DD> <MON> <STRIKE> <CALL|PUT>" in the signal.',
      );
    }

    final action = head.group(1) == 'BUY' ? TradeAction.buy : TradeAction.sell;
    final underlying = head.group(2)!;
    final expiry = _expiry(
      int.parse(head.group(3)!),
      _months[head.group(4)!]!,
      head.group(5),
    );
    final strike = double.parse(head.group(6)!);
    final type = head.group(7)!;
    final optionType =
        (type == 'CE' || type == 'CALL') ? OptionType.call : OptionType.put;

    final tail = text.substring(head.end);

    final entry = _entry.firstMatch(tail);
    if (entry == null) {
      throw SignalParseException('Could not find the entry price (e.g. "AT 400-420").');
    }
    var low = double.parse(entry.group(1)!);
    var high = entry.group(2) != null ? double.parse(entry.group(2)!) : low;
    if (low > high) (low, high) = (high, low);

    final slMatch = _sl.firstMatch(tail);
    final stopLoss = slMatch != null ? double.parse(slMatch.group(1)!) : null;

    final targets = <double>[];
    final tgtStart = _targetKeyword.firstMatch(tail);
    if (tgtStart != null) {
      final section = tail
          .substring(tgtStart.start)
          .replaceAll(_slTail, ' ')
          .replaceAll(_targetLabel, ' ');
      targets.addAll(_numbers.allMatches(section).map((m) => double.parse(m.group(1)!)));
    }

    final warnings = <String>[];
    final isBuy = action == TradeAction.buy;
    if (stopLoss == null) warnings.add('No stop loss found.');
    if (targets.isEmpty) warnings.add('No targets found.');
    if (stopLoss != null && (isBuy ? stopLoss >= low : stopLoss <= high)) {
      warnings.add('Stop loss is on the wrong side of the entry price.');
    }
    if (targets.any((t) => isBuy ? t <= high : t >= low)) {
      warnings.add('A target is on the wrong side of the entry price.');
    }

    return TradeSignal(
      action: action,
      underlying: underlying,
      expiry: expiry,
      strike: strike,
      optionType: optionType,
      entryLow: low,
      entryHigh: high,
      stopLoss: stopLoss,
      targets: targets,
      raw: input.trim(),
      warnings: warnings,
    );
  }

  DateTime _expiry(int day, int month, String? yearText) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    int year;
    if (yearText != null) {
      year = int.parse(yearText);
      if (year < 100) year += 2000;
    } else {
      year = today.year;
      if (DateTime(year, month, day).isBefore(today)) year++;
    }
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) {
      throw SignalParseException('Invalid expiry date: $day/$month/$year.');
    }
    return date;
  }
}
