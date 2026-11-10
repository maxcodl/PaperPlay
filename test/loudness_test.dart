import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/playback/loudness.dart';

void main() {
  test('parses gain text', () {
    expect(parseGainDb('-6.54 dB'), -6.54);
    expect(parseGainDb('+2,1 dB'), 2.1);
    expect(parseGainDb('nonsense'), isNull);
    expect(parseGainDb(null), isNull);
  });

  test('only attenuates', () {
    expect(normalizationFactor(null, 0), 1);
    expect(normalizationFactor(3, 0), 1);
    expect(normalizationFactor(-6.0206, 0), closeTo(0.5, 0.001));
    expect(normalizationFactor(-6.0206, 6.0206), closeTo(1, 0.001));
    expect(normalizationFactor(-6.0206, -6.0206), closeTo(0.25, 0.001));
  });
}
