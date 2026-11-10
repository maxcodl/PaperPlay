/// Counts wall-clock listening time, only while audio plays. Driven by a ~1s tick,
/// so skips, seeks, pauses and a suspended process can't inflate it.
class ListenRecorder {
  ListenRecorder(this.write, {this.flushEvery = const Duration(seconds: 15), this.onScrobble});

  /// Saves growth: [ms] listened and [plays] counted for [key] on [day].
  final Future<void> Function(String day, String key, int ms, int plays) write;
  final Duration flushEvery;

  /// Called once per listen of a song when it counts as a scrobble: half the song or
  /// 4 minutes heard, for songs of 30 s or more. [startedAt] is when it began.
  final void Function(String key, DateTime startedAt)? onScrobble;

  /// A gap longer than this between ticks isn't listening (sleep, killed process).
  static const maxGap = Duration(seconds: 5);

  DateTime? _last;
  String? _key;
  String _day = '';
  int _pendingMs = 0, _pendingPlays = 0, _sessionMs = 0;
  bool _counted = false, _scrobbled = false;
  DateTime _startedAt = DateTime.now();
  DateTime? _lastFlush;

  static String dayOf(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// [key] is the playing song, null when none. [durationSec] sets when a play counts:
  /// 30 s or half the song, whichever is less.
  Future<void> tick(DateTime now, {required bool playing, String? key, int durationSec = 0}) async {
    if (!playing || key == null) {
      await flush();
      _last = null;
      return;
    }
    if (key != _key || dayOf(now) != _day) {
      await flush();
      if (key != _key) {
        _sessionMs = 0;
        _counted = false;
        _scrobbled = false;
        _startedAt = now;
      }
      _key = key;
      _day = dayOf(now);
      _last = now;
      return;
    }
    final last = _last;
    _last = now;
    if (last == null) return;
    final gap = now.difference(last);
    if (gap <= Duration.zero || gap > maxGap) return;
    _pendingMs += gap.inMilliseconds;
    _sessionMs += gap.inMilliseconds;
    final need = durationSec > 0 ? (durationSec * 500).clamp(0, 30000) : 30000;
    if (!_counted && _sessionMs >= need) {
      _counted = true;
      _pendingPlays++;
    }
    if (!_scrobbled && durationSec >= 30 && _sessionMs >= (durationSec * 500).clamp(0, 240000)) {
      _scrobbled = true;
      onScrobble?.call(key, _startedAt);
    }
    if (now.difference(_lastFlush ??= now) >= flushEvery) await flush();
  }

  Future<void> flush() async {
    final key = _key;
    if (key == null || (_pendingMs == 0 && _pendingPlays == 0)) return;
    final ms = _pendingMs, plays = _pendingPlays;
    _pendingMs = 0;
    _pendingPlays = 0;
    _lastFlush = null;
    await write(_day, key, ms, plays);
  }
}
