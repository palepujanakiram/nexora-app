import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';

void main() {
  test('defaults', () {
    const s = AppSettings();
    expect(s.entryPriceMode, EntryPriceMode.high);
    expect(s.exitMode, ExitMode.withStopAndTarget);
    expect(s.targetIndex, 0);
    expect(s.corsProxy, '');
    expect(s.themeColor, ThemeColor.green);
  });

  test('copyWith with no arguments keeps every field', () {
    const s = AppSettings(
      entryPriceMode: EntryPriceMode.mid,
      exitMode: ExitMode.entryOnly,
      targetIndex: 2,
      corsProxy: 'p',
      themeColor: ThemeColor.slate,
    );
    final c = s.copyWith();
    expect(c.entryPriceMode, EntryPriceMode.mid);
    expect(c.exitMode, ExitMode.entryOnly);
    expect(c.targetIndex, 2);
    expect(c.corsProxy, 'p');
    expect(c.themeColor, ThemeColor.slate);
  });

  test('copyWith replaces each given field', () {
    final c = const AppSettings().copyWith(
      entryPriceMode: EntryPriceMode.low,
      exitMode: ExitMode.entryOnly,
      targetIndex: 1,
      corsProxy: 'https://proxy/',
      themeColor: ThemeColor.amber,
    );
    expect(c.entryPriceMode, EntryPriceMode.low);
    expect(c.exitMode, ExitMode.entryOnly);
    expect(c.targetIndex, 1);
    expect(c.corsProxy, 'https://proxy/');
    expect(c.themeColor, ThemeColor.amber);
  });

  test('enum labels and colours', () {
    expect(EntryPriceMode.values.map((e) => e.label), ['Low end', 'Middle', 'High end']);
    expect(ExitMode.entryOnly.label, 'Entry order only');
    expect(ExitMode.withStopAndTarget.label, 'Entry + stop loss & target (GTT)');
    expect(ThemeColor.green.label, 'Green');
    expect(ThemeColor.green.argb, 0xFF1E6F5C);
    expect(ThemeColor.values, hasLength(11));
    expect(ThemeColor.values.map((c) => c.argb).toSet(), hasLength(11), reason: 'colours are distinct');
  });
}
