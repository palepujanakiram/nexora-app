import '../../../common/domain/entities/app_settings.dart';
import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/entities/trade_signal.dart';
import '../../../common/domain/services/trade_pricing.dart';

class SignalState {
  const SignalState({
    this.signal,
    this.error,
    this.accounts = const [],
    this.selectionOverrides = const {},
    this.settings = const AppSettings(),
    this.busy = false,
    this.exitsSupported = true,
  });

  final TradeSignal? signal;
  final String? error;
  final List<BrokerAccount> accounts;

  /// Per-account checkbox overrides; unset accounts follow "Use by default".
  final Map<String, bool> selectionOverrides;
  final AppSettings settings;
  final bool busy;

  /// False on a server, which places the entry order only.
  final bool exitsSupported;

  bool isSelected(BrokerAccount a) => selectionOverrides[a.id] ?? a.enabled;

  List<BrokerAccount> get chosen => accounts.where(isSelected).toList();

  List<BrokerAccount> get chosenLive => chosen.where((a) => !a.paperMode).toList();

  bool get canExecute => signal != null && !busy && chosen.isNotEmpty;

  double? get limitPrice => signal == null ? null : TradePricing.entryPrice(signal!, settings.entryPriceMode);

  double? get exitTarget => signal == null ? null : TradePricing.targetFor(signal!, settings);

  bool get placesExits =>
      exitsSupported &&
      settings.exitMode == ExitMode.withStopAndTarget && signal?.stopLoss != null && exitTarget != null;

  SignalState copyWith({
    TradeSignal? signal,
    String? error,
    bool clearParse = false,
    List<BrokerAccount>? accounts,
    Map<String, bool>? selectionOverrides,
    AppSettings? settings,
    bool? busy,
  }) =>
      SignalState(
        signal: clearParse ? null : signal ?? this.signal,
        error: clearParse ? null : error ?? this.error,
        accounts: accounts ?? this.accounts,
        selectionOverrides: selectionOverrides ?? this.selectionOverrides,
        settings: settings ?? this.settings,
        busy: busy ?? this.busy,
        exitsSupported: exitsSupported,
      );
}
