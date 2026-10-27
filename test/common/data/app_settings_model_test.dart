import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/app_settings_model.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';

void main() {
  test('theme colour round-trips through JSON', () {
    const s = AppSettings(themeColor: ThemeColor.purple, targetIndex: 1);
    final back = AppSettingsModel.fromJson(AppSettingsModel.toJson(s));
    expect(back.themeColor, ThemeColor.purple);
    expect(back.targetIndex, 1);
  });

  test('settings saved before theme colour existed load with the default', () {
    final back = AppSettingsModel.fromJson({'entryPriceMode': 'low', 'exitMode': 'entryOnly'});
    expect(back.themeColor, ThemeColor.green);
    expect(back.entryPriceMode, EntryPriceMode.low);
  });

  test('unknown enum names fall back to defaults', () {
    final back = AppSettingsModel.fromJson({'themeColor': 'chartreuse'});
    expect(back.themeColor, ThemeColor.green);
  });
}
