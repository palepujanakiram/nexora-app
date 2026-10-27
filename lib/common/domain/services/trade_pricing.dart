import 'dart:math';

import '../entities/app_settings.dart';
import '../entities/trade_signal.dart';

/// Pricing rules shared by order placement and the signal preview.
abstract final class TradePricing {
  static double entryPrice(TradeSignal s, EntryPriceMode mode) => switch (mode) {
        EntryPriceMode.low => s.entryLow,
        EntryPriceMode.mid => (s.entryLow + s.entryHigh) / 2,
        EntryPriceMode.high => s.entryHigh,
      };

  /// The target used for the exit order; falls back to the last target when
  /// the signal has fewer than [AppSettings.targetIndex] + 1.
  static double? targetFor(TradeSignal s, AppSettings settings) =>
      s.targets.isEmpty ? null : s.targets[min(settings.targetIndex, s.targets.length - 1)];

  static double roundToTick(double price, double tick) =>
      double.parse(((price / tick).round() * tick).toStringAsFixed(2));
}
