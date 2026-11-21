import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signals_config.dart';

void main() {
  test('not configured without a --dart-define=EPS_SIGNALS_PROXY_URL', () {
    expect(EpsSignalsConfig.proxyUrl, isEmpty);
    expect(EpsSignalsConfig.isConfigured, isFalse);
  });
}
