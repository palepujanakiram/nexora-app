/// Which price inside the signal's entry range to use for the limit order.
enum EntryPriceMode {
  low('Low end'),
  mid('Middle'),
  high('High end');

  const EntryPriceMode(this.label);
  final String label;
}

enum ExitMode {
  entryOnly('Entry order only'),
  withStopAndTarget('Entry + stop loss & target (GTT)');

  const ExitMode(this.label);
  final String label;
}

/// Seed colours the user can pick for the app theme. Stored by name.
enum ThemeColor {
  green('Green', 0xFF1E6F5C),
  blue('Blue', 0xFF1565C0),
  indigo('Indigo', 0xFF3949AB),
  purple('Purple', 0xFF7B1FA2),
  pink('Pink', 0xFFC2185B),
  red('Red', 0xFFC62828),
  orange('Orange', 0xFFEF6C00),
  amber('Amber', 0xFFFFA000),
  teal('Teal', 0xFF00897B),
  brown('Brown', 0xFF6D4C41),
  slate('Slate', 0xFF546E7A);

  const ThemeColor(this.label, this.argb);
  final String label;
  final int argb;
}

class AppSettings {
  const AppSettings({
    this.entryPriceMode = EntryPriceMode.high,
    this.exitMode = ExitMode.withStopAndTarget,
    this.targetIndex = 0,
    this.corsProxy = '',
    this.themeColor = ThemeColor.green,
  });

  final EntryPriceMode entryPriceMode;
  final ExitMode exitMode;

  /// Which target (0 = TGT1) the GTT exit order uses.
  final int targetIndex;

  /// Prefix prepended to broker API URLs on web, where browsers block direct
  /// calls (CORS). Example: `https://my-proxy.example.com/`.
  final String corsProxy;

  final ThemeColor themeColor;

  AppSettings copyWith({
    EntryPriceMode? entryPriceMode,
    ExitMode? exitMode,
    int? targetIndex,
    String? corsProxy,
    ThemeColor? themeColor,
  }) =>
      AppSettings(
        entryPriceMode: entryPriceMode ?? this.entryPriceMode,
        exitMode: exitMode ?? this.exitMode,
        targetIndex: targetIndex ?? this.targetIndex,
        corsProxy: corsProxy ?? this.corsProxy,
        themeColor: themeColor ?? this.themeColor,
      );
}
