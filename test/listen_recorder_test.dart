import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/stats/listen_recorder.dart';

void main() {
  late List<(String, String, int, int)> out;
  late ListenRecorder r;
  final t0 = DateTime(2026, 1, 1, 12);

  setUp(() {
    out = [];
    r = ListenRecorder((d, k, ms, p) async => out.add((d, k, ms, p)));
  });

  int total(String k) => out.where((e) => e.$2 == k).fold(0, (a, e) => a + e.$3);

  test('skip at 0:20 counts 20 s and no play', () async {
    for (var i = 0; i <= 20; i++) {
      await r.tick(t0.add(Duration(seconds: i)), playing: true, key: 'a', durationSec: 200);
    }
    await r.tick(t0.add(const Duration(seconds: 21)), playing: true, key: 'b', durationSec: 200);
    expect(total('a'), 20000);
    expect(out.fold(0, (a, e) => a + e.$4), 0);
  });

  test('pause for an hour counts 0', () async {
    await r.tick(t0, playing: true, key: 'a');
    await r.tick(t0.add(const Duration(seconds: 1)), playing: true, key: 'a');
    await r.tick(t0.add(const Duration(seconds: 2)), playing: false, key: 'a');
    await r.tick(t0.add(const Duration(hours: 1)), playing: true, key: 'a');
    await r.tick(t0.add(const Duration(hours: 1, seconds: 1)), playing: true, key: 'a');
    await r.flush();
    expect(total('a'), 2000);
  });

  test('suspended process gap is ignored; a play counts once at 30 s', () async {
    for (var i = 0; i <= 40; i++) {
      await r.tick(t0.add(Duration(seconds: i)), playing: true, key: 'a', durationSec: 300);
    }
    await r.tick(t0.add(const Duration(hours: 5)), playing: true, key: 'a', durationSec: 300);
    await r.flush();
    expect(total('a'), 40000);
    expect(out.fold(0, (a, e) => a + e.$4), 1);
  });
}
