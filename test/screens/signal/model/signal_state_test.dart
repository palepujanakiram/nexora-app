import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/screens/signal/model/signal_state.dart';

import '../../../fakes.dart';

void main() {
  final parser = SignalParser(clock: () => DateTime(2026, 10, 27));
  final full = parser.parse('BUY SENSEX 29 OCT 2026 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600');
  final bare = parser.parse('BUY NIFTY 30 OCT 2026 25000 CE AT 100');

  group('selection', () {
    final live = testAccount();
    final paper = testAccount(id: 'p', paper: true);
    final off = testAccount(id: 'off', enabled: false);

    test('follows enabled flag until overridden', () {
      final s = SignalState(accounts: [live, paper, off]);
      expect(s.isSelected(live), isTrue);
      expect(s.isSelected(off), isFalse);
      expect(s.chosen.map((a) => a.id), ['a', 'p']);
      expect(s.chosenLive.map((a) => a.id), ['a']);

      final o = s.copyWith(selectionOverrides: {'a': false, 'off': true});
      expect(o.chosen.map((a) => a.id), ['p', 'off']);
      expect(o.chosenLive.map((a) => a.id), ['off']);
    });

    test('canExecute needs a signal, a chosen account and not busy', () {
      expect(SignalState(accounts: [live]).canExecute, isFalse);
      expect(SignalState(signal: full).canExecute, isFalse);
      expect(SignalState(signal: full, accounts: [off]).canExecute, isFalse);
      expect(SignalState(signal: full, accounts: [live]).canExecute, isTrue);
      expect(SignalState(signal: full, accounts: [live], busy: true).canExecute, isFalse);
    });
  });

  group('pricing', () {
    test('is null without a signal', () {
      const s = SignalState();
      expect(s.limitPrice, isNull);
      expect(s.exitTarget, isNull);
      expect(s.placesExits, isFalse);
    });

    test('uses the entry price mode and target index', () {
      final s = SignalState(
        signal: full,
        settings: const AppSettings(entryPriceMode: EntryPriceMode.mid, targetIndex: 1),
      );
      expect(s.limitPrice, 410);
      expect(s.exitTarget, 600);
      expect(s.placesExits, isTrue);
    });

    test('target index past the end falls back to the last target', () {
      final s = SignalState(signal: full, settings: const AppSettings(targetIndex: 2));
      expect(s.exitTarget, 600);
      expect(s.limitPrice, 420);
    });

    test('no exits in entry-only mode or without a stop loss / target', () {
      expect(SignalState(signal: full, settings: const AppSettings(exitMode: ExitMode.entryOnly)).placesExits,
          isFalse);
      final s = SignalState(signal: bare);
      expect(s.exitTarget, isNull);
      expect(s.placesExits, isFalse);
    });
  });

  test('copyWith keeps or replaces fields and clearParse drops signal and error', () {
    final s = SignalState(signal: full, error: 'x', accounts: [testAccount()], busy: true);
    final kept = s.copyWith();
    expect(kept.signal, same(full));
    expect(kept.error, 'x');
    expect(kept.accounts, hasLength(1));
    expect(kept.busy, isTrue);

    final cleared = s.copyWith(clearParse: true);
    expect(cleared.signal, isNull);
    expect(cleared.error, isNull);
    expect(cleared.accounts, hasLength(1));
    expect(cleared.busy, isTrue);

    final next = s.copyWith(
      signal: bare,
      error: 'y',
      accounts: const [],
      selectionOverrides: {'a': false},
      settings: const AppSettings(targetIndex: 2),
      busy: false,
    );
    expect(next.signal, same(bare));
    expect(next.error, 'y');
    expect(next.accounts, isEmpty);
    expect(next.selectionOverrides, {'a': false});
    expect(next.settings.targetIndex, 2);
    expect(next.busy, isFalse);
  });
}
