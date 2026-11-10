import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/stats/listen_recorder.dart';

void main() {
  test('scrobble fires once at half the song, and not for songs under 30 s', () async {
    final fired = <String>[];
    final r = ListenRecorder((a, b, c, d) async {}, onScrobble: (k, _) => fired.add(k));
    final t0 = DateTime(2026, 1, 1);
    for (var i = 0; i <= 100; i++) {
      await r.tick(t0.add(Duration(seconds: i)), playing: true, key: 'a', durationSec: 120);
    }
    for (var i = 0; i <= 20; i++) {
      await r.tick(t0.add(Duration(seconds: 200 + i)), playing: true, key: 'short', durationSec: 20);
    }
    expect(fired, ['a']);
  });
}
