import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/playback/equalizer.dart';

void main() {
  test('flat adds no processing', () => expect(mpvFilter([0, 0, 0, 0, 0]), ''));

  test('boost leaves headroom and ends in the limiter', () {
    final f = mpvFilter([6, 0, 0, 0, -3]);
    expect(f, startsWith('lavfi=[volume=-6.0dB,equalizer=f=60:t=q:w=1:g=6.0,'));
    expect(f, contains('f=14000:t=q:w=1:g=-3.0'));
    expect(f, endsWith('alimiter=limit=0.944]'));
  });

  test('a device band takes the nearest band by pitch', () {
    const g = [1.0, 2.0, 3.0, 4.0, 5.0];
    expect(gainAtFreq(g, 60), 1);
    expect(gainAtFreq(g, 1000), 3);
    expect(gainAtFreq(g, 16000), 5);
  });
}
