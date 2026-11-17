import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/card127_performance_probe.dart';

void main() {
  test('probe follows the compile-time opt-in and remains safe to call', () {
    const expected = bool.fromEnvironment(
      'CARD127_BENCHMARK',
      defaultValue: false,
    );

    expect(Card127PerformanceProbe.enabled, expected);
    expect(
      () => Card127PerformanceProbe.mark('card127_probe_flag_test'),
      returnsNormally,
    );
  });
}
