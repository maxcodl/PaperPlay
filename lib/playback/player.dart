import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:rxdart/rxdart.dart';

import '../library/db.dart';
import '../telegram/td_client.dart';
import '../stats/listen_recorder.dart';
import 'cache.dart';
import 'equalizer.dart';
import 'loudness.dart';
import 'td_source.dart';

/// What a connected device last said it's playing.
class RemoteState {
  const RemoteState(this.json, this.items);
  final Map<String, dynamic> json;

  /// Its queue, as `[chatId, messageId]` pairs.
  final List<List<int>> items;

  bool get playing => json['playing'] as bool? ?? false;

  /// The sound device it's using, such as its headphones.
  String? get outputName => json['output'] as String?;
  String? get title => json['title'] as String?;
  String? get artist => json['artist'] as String?;
  int get index => json['idx'] as int? ?? 0;
}

/// Which output to show when the device list opens: what's already chosen; or
/// this device if it's playing; or else whichever connected device is playing.
String? defaultOutput(String? target, bool localPlaying, Map<String, RemoteState> states) {
  if (target != null || localPlaying) return target;
  return states.entries.where((e) => e.value.playing).map((e) => e.key).firstOrNull;
}

/// Whether two versions of a song differ only in what the player never shows. The
/// row changes every few seconds while downloading, and redrawing each time flickers.
bool sameToShow(Song a, Song b) =>
    a == b.copyWith(cachedBytes: a.cachedBytes, lastPlayedAt: Value(a.lastPlayedAt), plays: a.plays, skips: a.skips);

class PlayerController {
  PlayerController(this._td, this._db, this._cache) {
    player.currentIndexStream.listen(_onIndex);
    player.durationStream.listen(_onDuration);
    player.positionStream.listen((p) {
      if (p > _heardOf) _heardOf = p;
    });
    player.playbackEventStream.listen((_) {}, onError: (Object e, _) => error.value = '$e');
    out = PlayerOutput._(this);
    player.playingStream.listen((playing) {
      _playTimer(playing);
      if (!playing) unawaited(_saveSession());
    });
    for (final Stream<Object?> s in [
      player.playingStream,
      player.processingStateStream,
      player.currentIndexStream,
      player.durationStream,
      player.shuffleModeEnabledStream,
      player.loopModeStream,
      player.speedStream,
      player.volumeStream,
      player.positionDiscontinuityStream,
    ]) {
      s.listen((_) => _schedulePublish());
    }
  }

  late final _listen = ListenRecorder((day, key, ms, plays) async {
    final origin = _origin ??= await _db.pref('device_id');
    if (origin == null) return;
    await _db.addListen(origin, day, key, ms, plays);
    onListenChanged?.call();
  }, onScrobble: (key, at) {
    final i = player.currentIndex;
    if (i != null && i < _localQueue.length && _localQueue[i].uniqueId == key) onScrobble?.call(_localQueue[i], at);
  });

  /// Run when a song has been listened to enough to scrobble.
  void Function(Song song, DateTime startedAt)? onScrobble;
  String? _origin;

  /// Run after listening time is saved, so the device link can pass it on.
  VoidCallback? onListenChanged;

  Timer? _playTick;
  var _playTicks = 0;

  /// The once-a-second work (listening time, state for other devices, saving the session)
  /// only runs while something plays, so a paused app has no timer waking it.
  void _playTimer(bool playing) {
    if (playing) {
      _playTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _listenTick();
        if (++_playTicks % _stateEvery.inSeconds == 0) {
          _publishState();
          unawaited(_saveSession());
        }
      });
    } else {
      _playTick?.cancel();
      _playTick = null;
      _listenTick(); // Settles the listening time up to the pause.
    }
  }

  void _listenTick() {
    final i = player.currentIndex;
    final song = i != null && i < _localQueue.length ? _localQueue[i] : null;
    unawaited(_listen.tick(
      DateTime.now(),
      playing: player.playing && player.processingState == ProcessingState.ready,
      key: song?.uniqueId,
      durationSec: song?.durationSec ?? 0,
    ));
  }

  static const _stateEvery = Duration(seconds: 5);

  final TdClient _td;
  final AppDb _db;
  final CacheManager _cache;

  /// This device's audio. The UI uses [out], which can also be another device.
  final _androidEq = Platform.isAndroid ? AndroidEqualizer() : null;
  late final player = AudioPlayer(
    audioPipeline: _androidEq == null ? null : AudioPipeline(androidAudioEffects: [_androidEq]),
  );
  late final equalizer = Equalizer(_db, _androidEq);

  /// Volume the listener chose; the player's own is that times [_trackGain].
  var userVolume = 1.0;
  var _trackGain = 1.0;
  final _gains = <String, double?>{};

  /// Per-track levelling: 'off' or 'track' (ReplayGain), plus a preamp in dB. Per device.
  var normMode = 'off';
  var normPreamp = 0.0;

  Future<void> loadNormalization() async {
    normMode = await _db.pref('norm_mode') ?? 'off';
    normPreamp = double.tryParse(await _db.pref('norm_preamp') ?? '') ?? 0;
  }

  Future<void> setNormalization({String? mode, double? preamp}) async {
    normMode = mode ?? normMode;
    normPreamp = preamp ?? normPreamp;
    await _db.setPref('norm_mode', normMode);
    await _db.setPref('norm_preamp', '$normPreamp');
    await _updateTrackGain();
  }

  Future<void> setUserVolume(double v) async {
    userVolume = v;
    out._volume.add(v);
    await player.setVolume(v * _trackGain);
  }

  /// Reads the song's ReplayGain once its start has arrived, trying a few times.
  Future<void> _updateTrackGain() async {
    final i = player.currentIndex;
    final song = i != null && i < _localQueue.length ? _localQueue[i] : null;
    if (normMode != 'track' || song == null) {
      _trackGain = 1;
      return player.setVolume(userVolume);
    }
    var known = _gains.containsKey(song.uniqueId);
    for (var tries = 0; !known && tries < 6; tries++) {
      await Future<void>.delayed(Duration(milliseconds: 400 * (tries + 1)));
      if (player.currentIndex != i) return;
      final path = await _cache.localPath(song);
      if (path == null) continue;
      final gain = readTrackGainDb(File(path));
      if (gain != null || tries == 5) {
        _gains[song.uniqueId] = gain;
        known = true;
      }
    }
    if (!known || player.currentIndex != i) return;
    _trackGain = normalizationFactor(_gains[song.uniqueId], normPreamp);
    await player.setVolume(userVolume * _trackGain);
  }

  /// Controls and state of the chosen output, here or on another device.
  late final PlayerOutput out;

  /// The queue on the chosen output.
  final queue = ValueNotifier<List<Song>>([]);

  /// The queue of this device's own [player].
  var _localQueue = <Song>[];

  /// The chosen device's id; null means this device.
  final target = ValueNotifier<String?>(null);

  /// What each connected device is playing, by device id.
  final remoteStates = ValueNotifier<Map<String, RemoteState>>(const {});

  /// Sends a message to a device. Set by the device link.
  void Function(String deviceId, Map<String, dynamic> message)? sendToDevice;

  /// Whether plays and skips are being learned from. Off means nothing is recorded.
  bool Function() countPlays = () => false;

  /// This device's sound output, shown on other devices.
  String? Function()? outputName;

  var _restoring = false;

  /// Remembers the queue, song and place, so the next launch can pick up there.
  Future<void> _saveSession() async {
    final i = player.currentIndex;
    if (_restoring || target.value != null || i == null || _localQueue.isEmpty) return;
    await _db.setPref(
      'last_session',
      jsonEncode({'items': _itemsOf(_localQueue), 'idx': i, 'ms': player.position.inMilliseconds}),
    );
  }

  /// Loads what was playing last time, paused at the same place.
  Future<void> restoreSession() async {
    if (_localQueue.isNotEmpty) return;
    _restoring = true;
    try {
      final raw = await _db.pref('last_session');
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final items = [for (final i in j['items'] as List) (i as List).cast<int>()];
      final songs = await _songsOf(items);
      if (songs.isEmpty) return;
      // Songs gone from the library shift the index, so find the saved one by its post.
      final saved = items[(j['idx'] as int).clamp(0, items.length - 1)];
      final at = songs.indexWhere((s) => s.chatId == saved[0] && s.messageId == saved[1]);
      await _load(songs, at < 0 ? 0 : at, at < 0 ? Duration.zero : Duration(milliseconds: j['ms'] as int), play: false);
    } catch (_) {
      // A damaged record just means starting empty.
    } finally {
      _restoring = false;
    }
  }

  void onOutputChanged() => _schedulePublish();

  /// Tells connected devices this device's state. Set by the device link.
  void Function(Map<String, dynamic> state)? onLocalState;

  Timer? _publishTimer;
  var _queueChanged = true;

  void _setLocalQueue(List<Song> songs) {
    _localQueue = songs;
    _queueChanged = true;
    if (target.value == null) queue.value = songs;
    _schedulePublish();
  }

  void _schedulePublish() {
    _publishTimer?.cancel();
    _publishTimer = Timer(const Duration(milliseconds: 250), _publishState);
  }

  void _publishState() {
    onLocalState?.call(localState(withQueue: _queueChanged));
    _queueChanged = false;
  }

  /// This device's playback as sent to others. The queue is only included when
  /// it changed, since it can be large.
  Map<String, dynamic> localState({required bool withQueue}) {
    final idx = player.currentIndex;
    final song = idx != null && idx < _localQueue.length ? _localQueue[idx] : null;
    return {
      'playing': player.playing,
      'proc': player.processingState.name,
      'pos': player.position.inMilliseconds,
      'dur': player.duration?.inMilliseconds,
      'buf': player.bufferedPosition.inMilliseconds,
      'idx': idx,
      'shuffle': player.shuffleModeEnabled,
      'loop': player.loopMode.name,
      'speed': player.speed,
      'volume': userVolume,
      'title': song?.title,
      'artist': song?.artist,
      'output': outputName?.call(),
      if (withQueue) 'queue': _itemsOf(_localQueue),
    };
  }

  static List<List<int>> _itemsOf(List<Song> songs) => [
        for (final s in songs) [s.chatId, s.messageId],
      ];

  /// A connected device reported its state.
  Future<void> onDeviceState(String deviceId, Map<String, dynamic> state) async {
    final raw = state['queue'] as List?;
    final items = raw == null
        ? remoteStates.value[deviceId]?.items ?? const <List<int>>[]
        : [for (final i in raw) (i as List).cast<int>()];
    remoteStates.value = {...remoteStates.value, deviceId: RemoteState(state, items)};
    if (target.value != deviceId) return;
    out._applyRemote(state);
    if (raw != null) queue.value = await _songsOf(items);
    await _showRemoteCurrent(items, state['idx'] as int?);
  }

  Future<List<Song>> _songsOf(List<List<int>> items) async {
    final songs = <Song>[];
    for (final i in items) {
      final s = await _db.song(i[0], i[1]);
      if (s != null) songs.add(s);
    }
    return songs;
  }

  Future<void> _showRemoteCurrent(List<List<int>> items, int? idx) async {
    if (idx == null || idx >= items.length) return;
    final song = await _db.song(items[idx][0], items[idx][1]);
    if (song != null && target.value != null) current.value = song;
  }

  /// Playing together: this device leads and every connected device follows it, in step.
  final groupOn = ValueNotifier(false);

  /// Sends a command to every connected device. Set by the device link.
  void Function(Map<String, dynamic> message)? sendToAll;

  /// How far a device's clock is ahead of this one's, in milliseconds. Set by the device link.
  int Function(String deviceId) clockOffsetOf = (_) => 0;

  final _groupSubs = <StreamSubscription<Object?>>[];
  Timer? _groupTimer, _groupSoonTimer;
  var _groupTicks = 0;

  Future<void> setGroup(bool on) async {
    if (on == groupOn.value) return;
    if (on && target.value != null) await selectOutput(null);
    groupOn.value = on;
    for (final s in _groupSubs) {
      unawaited(s.cancel());
    }
    _groupSubs.clear();
    _groupTimer?.cancel();
    if (on) {
      _groupSubs
        ..add(player.playingStream.listen((_) => groupSoon()))
        ..add(player.currentIndexStream.listen((_) => groupSoon()))
        ..add(player.positionDiscontinuityStream.listen((_) => groupSoon()));
      _groupTimer = Timer.periodic(const Duration(seconds: 2), (_) => _groupTick());
      groupSoon();
    } else {
      sendToAll?.call({'t': 'cmd', 'op': 'groupOff'});
    }
  }

  /// Tells the others what is playing and where, a moment after something changed, so a burst
  /// of changes (a skip, a seek) goes out once.
  void groupSoon() {
    if (!groupOn.value) return;
    _groupSoonTimer?.cancel();
    _groupSoonTimer = Timer(const Duration(milliseconds: 120), () => _groupSend(full: true));
  }

  void _groupTick() {
    if (!groupOn.value || !player.playing) return;
    // The whole queue now and then, in case a device joined or missed one.
    _groupSend(full: ++_groupTicks % 5 == 0);
  }

  void _groupSend({required bool full}) {
    if (!groupOn.value) return;
    sendToAll?.call({
      't': 'cmd',
      'op': full ? 'group' : 'groupTick',
      if (full) 'items': _itemsOf(_localQueue),
      'idx': player.currentIndex ?? 0,
      'pos': player.position.inMilliseconds,
      'playing': player.playing,
      // This device's clock when the position was read; followers allow for the time since.
      'at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// The leader said what is playing. Starts it at the right place, and keeps this device
  /// within a few hundredths of a second of the leader: a small drift is corrected by
  /// playing a little faster or slower, a big one by jumping.
  Future<void> _followGroup(Map<String, dynamic> c, {required bool full}) async {
    if (groupOn.value) return; // Two leaders: this one keeps leading.
    final idx = c['idx'] as int, playing = c['playing'] as bool;
    final leaderNow = DateTime.now().millisecondsSinceEpoch + clockOffsetOf(c['from'] as String? ?? '');
    final expected = Duration(milliseconds: (c['pos'] as int) + (playing ? leaderNow - (c['at'] as int) : 0));
    if (full) {
      final items = [for (final i in c['items'] as List) (i as List).cast<int>()];
      if (jsonEncode(items) != jsonEncode(_itemsOf(_localQueue)) || player.currentIndex != idx) {
        final songs = await _songsOf(items);
        if (songs.isEmpty) return;
        await _load(songs, idx.clamp(0, songs.length - 1), expected, play: playing);
        return;
      }
    } else if (player.currentIndex != idx) {
      return; // Not on the same song yet: the next full message loads it.
    }
    if (!playing) {
      if (player.playing) await player.pause();
      if ((expected - player.position).abs() > const Duration(milliseconds: 100)) await player.seek(expected);
      if (player.speed != 1) await player.setSpeed(1);
      return;
    }
    if (!player.playing) unawaited(player.play());
    final diff = expected - player.position; // Positive: this device is behind.
    if (diff.abs() > const Duration(milliseconds: 250)) {
      await player.seek(expected);
      if (player.speed != 1) await player.setSpeed(1);
    } else if (diff.abs() > const Duration(milliseconds: 25)) {
      await player.setSpeed(1 + (diff.inMilliseconds / 4000).clamp(-0.05, 0.05));
    } else if (player.speed != 1) {
      await player.setSpeed(1);
    }
  }

  /// A command from a connected device, for this device's own [player].
  Future<void> onDeviceCommand(Map<String, dynamic> c) async {
    switch (c['op']) {
      case 'group':
        await _followGroup(c, full: true);
      case 'groupTick':
        await _followGroup(c, full: false);
      case 'groupOff':
        if (!groupOn.value) {
          await player.pause();
          if (player.speed != 1) await player.setSpeed(1);
        }
      case 'play':
        unawaited(player.play());
      case 'pause':
        await player.pause();
      case 'seek':
        await player.seek(Duration(milliseconds: c['ms'] as int), index: c['idx'] as int?);
      case 'next':
        await player.seekToNext();
      case 'prev':
        await player.seekToPrevious();
      case 'shuffle':
        if (c['on'] as bool) await player.shuffle();
        await player.setShuffleModeEnabled(c['on'] as bool);
      case 'loop':
        await player.setLoopMode(LoopMode.values.byName(c['mode'] as String));
      case 'speed':
        await player.setSpeed((c['value'] as num).toDouble());
      case 'volume':
        await setUserVolume((c['value'] as num).toDouble());
      case 'queue':
        final items = [for (final i in c['items'] as List) (i as List).cast<int>()];
        await _load(
          await _songsOf(items),
          c['idx'] as int,
          Duration(milliseconds: c['ms'] as int? ?? 0),
          play: c['play'] as bool? ?? true,
        );
      case 'playNext':
        final s = await _db.song(c['chatId'] as int, c['messageId'] as int);
        if (s != null) await _playNextLocal(s);
      case 'remove':
        await _removeLocal(c['index'] as int);
      case 'move':
        await _moveLocal(c['from'] as int, c['to'] as int);
    }
  }

  void _command(Map<String, dynamic> c) {
    final id = target.value;
    if (id != null) sendToDevice?.call(id, {'t': 'cmd', ...c});
  }

  /// Moves playback to [deviceId], or to this device when null. Whichever
  /// device is playing hands over its queue and position.
  Future<void> selectOutput(String? deviceId) async {
    final from = target.value;
    if (from == deviceId) return;
    if (deviceId != null && groupOn.value) await setGroup(false);
    final mirror = from == null ? null : remoteStates.value[from];
    final List<List<int>> items;
    final int idx;
    final int ms;
    final bool playing;
    if (from == null) {
      items = _itemsOf(_localQueue);
      idx = player.currentIndex ?? 0;
      ms = player.position.inMilliseconds;
      playing = player.playing;
    } else {
      items = mirror?.items ?? const [];
      idx = mirror?.index ?? 0;
      ms = out.position.inMilliseconds;
      playing = mirror?.playing ?? false;
      sendToDevice?.call(from, {'t': 'cmd', 'op': 'pause'});
    }
    if (from == null) await player.pause();

    if (deviceId == null) {
      target.value = null;
      out._useLocal();
      queue.value = _localQueue;
      final songs = await _songsOf(items);
      if (songs.isEmpty) {
        final i = player.currentIndex;
        current.value = i != null && i < _localQueue.length ? _localQueue[i] : null;
        return;
      }
      await _load(songs, idx.clamp(0, songs.length - 1), Duration(milliseconds: ms), play: playing);
      return;
    }

    final known = remoteStates.value[deviceId];
    target.value = deviceId;
    // A paused device here shouldn't replace what the chosen device is playing.
    if (items.isNotEmpty && (playing || known == null || known.items.isEmpty)) {
      sendToDevice?.call(deviceId, {
        't': 'cmd',
        'op': 'queue',
        'items': items,
        'idx': idx,
        'ms': ms,
        'play': playing,
      });
      queue.value = await _songsOf(items);
      await _showRemoteCurrent(items, idx);
    } else if (known != null) {
      out._applyRemote(known.json);
      queue.value = await _songsOf(known.items);
      await _showRemoteCurrent(known.items, known.json['idx'] as int?);
    }
  }

  /// A device left. If it was the output, playback comes back here paused, at
  /// the same place, so nothing starts playing unexpectedly.
  Future<void> onDeviceLeft(String deviceId) async {
    final mirror = remoteStates.value[deviceId];
    if (target.value == deviceId) {
      remoteStates.value = {
        ...remoteStates.value,
        if (mirror != null)
          deviceId: RemoteState({...mirror.json, 'playing': false}, mirror.items),
      };
      await selectOutput(null);
    }
    remoteStates.value = {...remoteStates.value}..remove(deviceId);
  }


  /// The playing song, kept current with library changes such as a new cover.
  final current = ValueNotifier<Song?>(null);
  final error = ValueNotifier<String?>(null);

  /// When the sleep timer will pause playback; null when it's off.
  final sleepAt = ValueNotifier<DateTime?>(null);
  Timer? _sleepTimer;
  StreamSubscription<Song?>? _currentRow;

  /// Run when a song starts, to fetch a full-size cover for the player.
  void Function(Song)? onSongStarted;

  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    sleepAt.value = after == null ? null : DateTime.now().add(after);
    if (after == null) return;
    _sleepTimer = Timer(after, () {
      sleepAt.value = null;
      out.pause();
    });
  }

  Future<void> playShuffled(List<Song> songs) => play([...songs]..shuffle(), 0);

  Future<void> toggleFavorite(Song s) =>
      _db.updateSong(s, SongsCompanion(favorite: Value(!s.favorite)));

  Future<void> removeFromQueue(int index) async {
    if (target.value != null) return _command({'op': 'remove', 'index': index});
    await _removeLocal(index);
  }

  Future<void> _removeLocal(int index) async {
    if (index == player.currentIndex || index >= _localQueue.length) return;
    _setLocalQueue([..._localQueue]..removeAt(index));
    await player.removeAudioSourceAt(index);
  }

  Future<void> moveInQueue(int from, int to) async {
    if (target.value != null) return _command({'op': 'move', 'from': from, 'to': to});
    await _moveLocal(from, to);
  }

  Future<void> _moveLocal(int from, int to) async {
    final list = [..._localQueue];
    list.insert(to, list.removeAt(from));
    _setLocalQueue(list);
    await player.moveAudioSource(from, to);
  }

  // Bounded window, since each source registers with the local proxy.
  static const _before = 10, _after = 40;

  AudioSource _source(Song s) => TdAudioSource(
        s,
        _td,
        _cache,
        tag: MediaItem(
          id: '${s.chatId}_${s.messageId}',
          title: s.title,
          artist: s.artist,
          album: s.album,
          artUri: s.coverPath == null ? null : Uri.file(s.coverPath!),
          duration: s.durationSec > 0 ? Duration(seconds: s.durationSec) : null,
        ),
      );

  /// Bumped by every request to play something. Tapping 10 or 20 songs in a row would
  /// otherwise load a queue for each and start downloads nobody listens to; instead the
  /// last tap wins, and the earlier ones never reach TDLib.
  var _playToken = 0;
  Timer? _prefetchTimer;
  static const _tapSettle = Duration(milliseconds: 180);

  Future<void> play(List<Song> songs, int index) async {
    final token = ++_playToken;
    if (target.value == null && index >= 0 && index < songs.length) current.value = songs[index];
    await Future<void>.delayed(_tapSettle);
    if (token != _playToken) return;
    final start = max(0, index - _before);
    final end = min(songs.length, index + _after);
    final window = songs.sublist(start, end);
    if (target.value != null) {
      queue.value = window;
      current.value = songs[index];
      return _command({
        'op': 'queue',
        'items': _itemsOf(window),
        'idx': index - start,
        'ms': 0,
        'play': true,
      });
    }
    await _load(window, index - start, Duration.zero, play: true, token: token, rest: songs.sublist(end));
  }

  /// Songs after the loaded window, added a few at a time as playback nears its end, so a
  /// queue of thousands never registers thousands of sources.
  var _rest = const <Song>[];
  static const _topUpAt = 12, _topUpBy = 30;

  Future<void> _topUp(int index) async {
    if (_rest.isEmpty || index < _localQueue.length - _topUpAt) return;
    final chunk = _rest.take(_topUpBy).toList();
    _rest = _rest.sublist(chunk.length);
    _setLocalQueue([..._localQueue, ...chunk]);
    try {
      await player.addAudioSources([for (final s in chunk) _source(s)]);
    } catch (e) {
      error.value = '$e';
    }
  }

  Future<void> _load(List<Song> songs, int index, Duration position,
      {required bool play, int? token, List<Song> rest = const []}) async {
    _rest = rest;
    _setLocalQueue(songs);
    try {
      await player.setAudioSources(
        [for (final s in songs) _source(s)],
        initialIndex: index,
        initialPosition: position,
      );
      // A later tap replaced this one while it loaded: that one starts playing, not this.
      if (token != null && token != _playToken) return;
      if (play) unawaited(player.play());
    } catch (e) {
      error.value = '$e';
    }
  }

  Future<void> playNext(Song s) async {
    if (target.value != null) {
      return _command({'op': 'playNext', 'chatId': s.chatId, 'messageId': s.messageId});
    }
    await _playNextLocal(s);
  }

  Future<void> _playNextLocal(Song s) async {
    if (_localQueue.isEmpty) return _load([s], 0, Duration.zero, play: true);
    final at = (player.currentIndex ?? -1) + 1;
    _setLocalQueue([..._localQueue]..insert(at, s));
    await player.insertAudioSource(at, _source(s));
  }

  var _heardOf = Duration.zero;

  /// Counts the song just left: most of it heard is a play, little of it a skip,
  /// and anything between says nothing.
  Future<void> _countPrevious() async {
    if (!countPlays()) return;
    final index = _lastIndex;
    if (index == null || index >= _localQueue.length) return;
    final song = _localQueue[index];
    final total = song.durationSec;
    if (total <= 0) return;
    final heard = _heardOf.inSeconds / total;
    if (heard >= 0.6) await _db.countPlay(song, finished: true);
    if (heard < 0.25 && _heardOf >= const Duration(seconds: 2)) await _db.countPlay(song, finished: false);
  }

  int? _lastIndex;

  Future<void> _onIndex(int? index) async {
    final previous = current.value;
    if (index != _lastIndex) {
      await _countPrevious();
      _lastIndex = index;
      _heardOf = Duration.zero;
    }
    if (index == null || index >= _localQueue.length) return;
    final song = _localQueue[index];
    if (previous?.uniqueId == song.uniqueId && _currentRow != null) return;
    // The queue's copy can be old, and showing its cover first would flash it.
    final row = await _db.song(song.chatId, song.messageId);
    if (target.value == null) current.value = row ?? song;
    await _currentRow?.cancel();
    _currentRow = _db.watchSong(song.chatId, song.messageId).listen((row) {
      if (row == null || target.value != null) return;
      final shown = current.value;
      if (shown == null || !sameToShow(shown, row)) current.value = row;
    });
    onSongStarted?.call(song);
    unawaited(_topUp(index));
    // A few seconds in, so the next file never competes with this one's start.
    _prefetchTimer?.cancel();
    final nextSong = player.nextIndex;
    if (nextSong != null && nextSong < _localQueue.length && target.value == null) {
      final upcoming = _localQueue[nextSong];
      _prefetchTimer = Timer(const Duration(seconds: 6), () {
        if (player.currentIndex == index) unawaited(_cache.prefetch(upcoming));
      });
    }
    unawaited(_updateTrackGain());
    final next = player.nextIndex;
    _cache.protectedIds = {
      song.uniqueId,
      if (next != null && next < _localQueue.length) _localQueue[next].uniqueId,
    };
    await _db.updateSong(
      song,
      SongsCompanion(lastPlayedAt: Value(DateTime.now().millisecondsSinceEpoch)),
    );
    if (previous != null && previous.uniqueId != song.uniqueId) {
      await _cache.cancelIfNotPinned(previous);
    }
  }

  /// Files sent as documents have no duration in Telegram; playback finds it,
  /// which also makes them eligible for a metadata match again.
  Future<void> _onDuration(Duration? d) async {
    final index = player.currentIndex;
    final song = index != null && index < _localQueue.length ? _localQueue[index] : null;
    if (d == null || d == Duration.zero || song == null) return;
    final row = await _db.song(song.chatId, song.messageId);
    if (row == null || row.durationSec != 0) return;
    await _db.updateSong(
      row,
      SongsCompanion(
        durationSec: Value(d.inSeconds),
        enrichState: Value(row.userEdited ? row.enrichState : EnrichState.pending),
      ),
    );
    onDurationLearned?.call();
  }

  VoidCallback? onDurationLearned;
}

/// The chosen output, with the same API as [AudioPlayer] for what the UI needs.
/// Controls go to this device's player or to the chosen device, and state comes
/// back the same way, so screens don't need to know which one it is.
class PlayerOutput {
  PlayerOutput._(this._c) {
    final p = _c.player;
    void local<T>(Stream<T> from, void Function(T) to) => from.listen((v) {
          if (_isLocal) to(v);
        });
    local(p.positionStream, _position.add);
    local(p.playerStateStream, _state.add);
    local(p.shuffleModeEnabledStream, _shuffle.add);
    local(p.loopModeStream, _loop.add);
    local(p.speedStream, _speed.add);
  }

  final PlayerController _c;
  final _position = BehaviorSubject<Duration>.seeded(Duration.zero);
  final _state = BehaviorSubject<PlayerState>.seeded(PlayerState(false, ProcessingState.idle));
  final _shuffle = BehaviorSubject<bool>.seeded(false);
  final _loop = BehaviorSubject<LoopMode>.seeded(LoopMode.off);
  final _speed = BehaviorSubject<double>.seeded(1);
  final _volume = BehaviorSubject<double>.seeded(1);

  Duration? _remoteDuration;
  var _remoteBuffered = Duration.zero;
  var _anchor = Duration.zero;
  var _anchorAt = DateTime.now();
  Timer? _ticker;

  bool get _isLocal => _c.target.value == null;

  Stream<Duration> get positionStream => _position.stream;
  Stream<PlayerState> get playerStateStream => _state.stream;
  Stream<bool> get playingStream => _state.stream.map((s) => s.playing).distinct();
  Stream<bool> get shuffleModeEnabledStream => _shuffle.stream;
  Stream<LoopMode> get loopModeStream => _loop.stream;
  Stream<double> get speedStream => _speed.stream;
  Stream<double> get volumeStream => _volume.stream;

  Duration get position => _position.value;
  PlayerState get playerStateSnapshot => _state.value;
  bool get playing => _state.value.playing;
  double get speed => _speed.value;
  double get volume => _volume.value;
  Duration? get duration => _isLocal ? _c.player.duration : _remoteDuration;
  Duration get bufferedPosition => _isLocal ? _c.player.bufferedPosition : _remoteBuffered;

  Future<void> play() async {
    if (_isLocal) return _c.player.play();
    _c._command({'op': 'play'});
  }

  Future<void> pause() async {
    if (_isLocal) return _c.player.pause();
    _c._command({'op': 'pause'});
  }

  Future<void> seek(Duration? position, {int? index}) async {
    if (_isLocal) {
      await _c.player.seek(position, index: index);
      _c.groupSoon();
      return;
    }
    _c._command({'op': 'seek', 'ms': (position ?? Duration.zero).inMilliseconds, 'idx': index});
    // Shows the new place at once instead of after the device replies.
    _anchor = position ?? Duration.zero;
    _anchorAt = DateTime.now();
    _position.add(_anchor);
  }

  Future<void> seekToNext() async {
    if (_isLocal) return _c.player.seekToNext();
    _c._command({'op': 'next'});
  }

  Future<void> seekToPrevious() async {
    if (_isLocal) return _c.player.seekToPrevious();
    _c._command({'op': 'prev'});
  }

  /// Shuffling happens with [setShuffleModeEnabled] on another device.
  Future<void> shuffle() async {
    if (_isLocal) await _c.player.shuffle();
  }

  Future<void> setShuffleModeEnabled(bool on) async {
    if (_isLocal) return _c.player.setShuffleModeEnabled(on);
    _c._command({'op': 'shuffle', 'on': on});
  }

  Future<void> setLoopMode(LoopMode mode) async {
    if (_isLocal) return _c.player.setLoopMode(mode);
    _c._command({'op': 'loop', 'mode': mode.name});
  }

  Future<void> setSpeed(double value) async {
    if (_isLocal) return _c.player.setSpeed(value);
    _c._command({'op': 'speed', 'value': value});
  }

  Future<void> setVolume(double value) async {
    if (_isLocal) return _c.setUserVolume(value);
    _c._command({'op': 'volume', 'value': value});
    _volume.add(value);
  }

  void _applyRemote(Map<String, dynamic> s) {
    final proc = ProcessingState.values.byName(s['proc'] as String);
    _state.add(PlayerState(s['playing'] as bool, proc));
    _shuffle.add(s['shuffle'] as bool);
    _loop.add(LoopMode.values.byName(s['loop'] as String));
    _speed.add((s['speed'] as num).toDouble());
    _volume.add((s['volume'] as num).toDouble());
    final dur = s['dur'] as int?;
    _remoteDuration = dur == null ? null : Duration(milliseconds: dur);
    _remoteBuffered = Duration(milliseconds: s['buf'] as int);
    // Timed from arrival, not the sender's clock, which may disagree with ours.
    _anchor = Duration(milliseconds: s['pos'] as int);
    _anchorAt = DateTime.now();
    _position.add(_anchor);
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_isLocal || !playing) return;
      final moved = DateTime.now().difference(_anchorAt) * _speed.value;
      _position.add(_anchor + moved);
    });
  }

  void _useLocal() {
    _ticker?.cancel();
    _ticker = null;
    final p = _c.player;
    _position.add(p.position);
    _state.add(p.playerState);
    _shuffle.add(p.shuffleModeEnabled);
    _loop.add(p.loopMode);
    _speed.add(p.speed);
    _volume.add(_c.userVolume);
  }
}
