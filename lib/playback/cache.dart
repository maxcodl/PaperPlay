import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart' show Value;

import '../library/audio_info.dart';
import '../library/db.dart';
import '../library/mood.dart' show stableHash;
import '../library/scanner.dart';
import '../log.dart';
import '../metadata/cover_sources.dart';
import '../telegram/bot_pool.dart';
import '../telegram/td_client.dart';

class CacheEntry<K> {
  const CacheEntry(this.key, this.bytes, this.lastPlayedAt, {this.pinned = false});
  final K key;
  final int bytes;
  final int? lastPlayedAt;
  final bool pinned;
}

/// Keys to evict, least recently played first, until unpinned bytes fit
/// [limit]. Pinned bytes don't count towards the limit and are never evicted;
/// [protected] entries count but are skipped, so the cache can stay over limit.
List<K> selectEvictions<K>(List<CacheEntry<K>> entries, int limit, Set<K> protected) {
  final unpinned = entries.where((e) => !e.pinned).toList()
    ..sort((a, b) => (a.lastPlayedAt ?? 0).compareTo(b.lastPlayedAt ?? 0));
  var total = unpinned.fold<int>(0, (sum, e) => sum + e.bytes);
  final evict = <K>[];
  for (final e in unpinned) {
    if (total <= limit) break;
    if (protected.contains(e.key)) continue;
    evict.add(e.key);
    total -= e.bytes;
  }
  return evict;
}

/// Tracks TDLib's files dir as the song cache. deleteFile only removes the
/// local copy; the message in Telegram is untouched.
class CacheManager {
  CacheManager(this._td, this._db, {BotPool? pool}) : _pool = pool {
    _td.updatesOf('updateFile').listen((u) => _onFile(u['file'] as Json));
    pool?.updatesOf('updateFile').listen((e) => _onFile(e.$2['file'] as Json));
  }

  Timer? _flushTimer;

  final TdClient _td;
  final BotPool? _pool;
  final AppDb _db;
  final _sizes = <String, int>{};

  /// How long the bot tries to reach Telegram before using its stored file id.
  /// Bots keep no local message database, so this is what makes offline play work.
  static const _botLookup = Duration(seconds: 4);
  var _enforcing = false;
  var _recent = <String>{};

  /// Every bot that holds files on this device, main first.
  List<TdClient> get _allBots => [_td, ...?_pool?.extras.value.map((e) => e.client)];

  /// The bot that handles a song's file: the same one every time, so a song is downloaded
  /// once, not once per bot. The main bot stands in while that bot isn't logged in.
  /// Bots can't read each other's posts, so which bot can read a song is learned: the one
  /// that last got its file is used again.
  final _reader = <String, TdClient>{};

  TdClient botFor(Song s) {
    final known = _reader[s.uniqueId];
    if (known != null) return known;
    final bots = _allBots;
    if (bots.length < 2) return _td;
    final bot = bots[stableHash(s.uniqueId) % bots.length];
    return bot == _td || (_pool?.ready.contains(bot) ?? false) ? bot : _td;
  }

  /// uniqueIds of songs that must stay on disk: current and next in queue.
  Set<String> protectedIds = {};

  void _onFile(Json file) {
    final id = (file['remote'] as Json)['unique_id'] as String;
    if (id.isNotEmpty) {
      _sizes[id] = (file['local'] as Json)['downloaded_size'] as int;
      // Only while a download is moving: an idle app has no timer.
      _flushTimer ??= Timer(const Duration(seconds: 5), () {
        _flushTimer = null;
        unawaited(_flush());
      });
    }
  }

  Future<void> _flush() async {
    if (_sizes.isEmpty) return;
    final batch = Map.of(_sizes);
    _sizes.clear();
    // Files that just downloaded something may be streaming right now: deleting one
    // makes the player report "Connection aborted".
    _recent = batch.keys.toSet();
    for (final e in batch.entries) {
      await _db.setCachedBytes(e.key, e.value);
    }
    await enforce();
  }

  Future<void> enforce({int? limit}) async {
    if (_enforcing) return;
    _enforcing = true;
    try {
      final rows = await _db.cachedSongs();
      final byId = {for (final s in rows) s.uniqueId: s};
      final evict = selectEvictions(
        [
          for (final s in rows)
            CacheEntry(s.uniqueId, s.cachedBytes, s.lastPlayedAt, pinned: s.pinned),
        ],
        limit ?? await _db.cacheLimit(),
        limit == 0 ? protectedIds : {...protectedIds, ..._recent},
      );
      for (final id in evict) {
        await _evict(byId[id]!);
      }
    } finally {
      _enforcing = false;
    }
  }

  Future<int> _fileId(Song s) async => (await fileOf(s))['id'] as int;

  /// Deletes the song's downloaded file from every bot, since the bot that holds it can
  /// change when bots are added or removed.
  Future<void> _evict(Song s) async {
    var failed = false;
    for (final bot in [botFor(s), ..._allBots.where((b) => b != botFor(s))]) {
      if (bot != _td && !(_pool?.ready.contains(bot) ?? false)) continue;
      try {
        await bot.call({'@type': 'deleteFile', 'file_id': (await _fileWith(bot, s))['id']});
      } on TdError {
        failed = bot == botFor(s); // Retried on the next enforce pass.
      } on TimeoutException {
        // Offline.
      }
    }
    if (failed) return;
    _sizes.remove(s.uniqueId);
    await _db.setCachedBytes(s.uniqueId, 0);
  }

  Future<Json> _fileWith(TdClient bot, Song s) async {
    final message = await bot.call({
      '@type': 'getMessage',
      'chat_id': s.chatId,
      'message_id': s.messageId,
    }).timeout(_botLookup);
    return payloadFile(audioPayload(message)!);
  }

  /// Current TDLib file of [s], read through its message. File ids don't
  /// outlive a TDLib session, so they aren't stored. Removes songs whose
  /// message was deleted.
  // A deleted song's cached bytes stay on disk until logout; add a cleanup
  // pass if that ever adds up.
  Future<Json> fileOf(Song s) async => (await fileAndBot(s)).$1;

  /// The file with the bot whose file it is: a file id means nothing to another bot.
  Future<(Json, TdClient)> fileAndBot(Song s) async {
    final first = botFor(s);
    final readers = [first, ...[_td, ...?_pool?.ready].toSet().where((b) => b != first)];
    TdError? notFound;
    var everyNotFound = true;
    for (final bot in readers) {
      try {
        final file = await _fileWith(bot, s);
        _reader[s.uniqueId] = bot;
        return (file, bot);
      } on TimeoutException {
        everyNotFound = false; // Offline.
        break;
      } on TdError catch (e) {
        if (e.code == 404) {
          notFound = e;
        } else {
          everyNotFound = false;
        }
      }
    }
    // Only when every bot says it isn't there is the post gone: a bot can't see another
    // bot's posts, so one bot's "not found" proves nothing.
    if (everyNotFound && notFound != null) {
      // The song may live on: moved to another topic, or kept by a repeat of the file,
      // which a queue's old copy of [s] can't know.
      await _db.postDeleted(s.chatId, s.messageId);
      final current = await _db.songByUniqueId(s.uniqueId);
      if (current != null) return fileAndBot(current);
      throw notFound;
    }
    return (await _td.call({'@type': 'getRemoteFile', 'remote_file_id': s.remoteId}), _td);
  }

  /// Sample rate read from the file's header, when the whole file is on this
  /// device. Null otherwise: it isn't worth a download just to show this.
  Future<int?> sampleRate(Song s) async {
    if (s.cachedBytes < s.size) return null;
    try {
      final local = (await fileOf(s))['local'] as Json;
      if (local['is_downloading_completed'] != true) return null;
      return readMetadata(File(local['path'] as String), getImage: false).sampleRate;
    } catch (_) {
      return null; // Unreadable headers just leave this line out.
    }
  }

  /// Files posted without a length (sent as documents, or by tools that skip it) are
  /// downloaded, read for their length and saved with it; the song then gets another go
  /// at an online match, which needs the length. A file that wasn't here already goes
  /// again afterwards, unless pinned. Returns the length in seconds, or null.
  /// Whether the last [learnDuration] failed because the file itself can't be read, as
  /// opposed to the connection.
  bool lastLengthUnreadable = false;

  Future<int?> learnDuration(Song s, {void Function(String stage, double? fraction)? onStage}) async {
    lastLengthUnreadable = false;
    final wasCached = s.cachedBytes > 0;
    StreamSubscription<Json>? progress;
    try {
      final (file, bot) = await fileAndBot(s);
      onStage?.call('Downloading', 0);
      progress = bot.updatesOf('updateFile').map((u) => u['file'] as Json).where((f) => f['id'] == file['id']).listen((f) {
        final total = (f['size'] as int) > 0 ? f['size'] as int : f['expected_size'] as int;
        if (total > 0) onStage?.call('Downloading', ((f['local'] as Json)['downloaded_size'] as int) / total);
      });
      final done = await bot.call({
        '@type': 'downloadFile',
        'file_id': file['id'],
        'priority': 1,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      });
      final local = done['local'] as Json;
      final path = local['path'] as String? ?? '';
      if (path.isEmpty || local['is_downloading_completed'] != true) return null;
      onStage?.call('Reading the file', null);
      final length = readMetadata(File(path), getImage: false).duration?.inSeconds ?? 0;
      if (length <= 0) return null;
      final row = await _db.song(s.chatId, s.messageId);
      if (row == null) return null;
      await _db.updateSong(
        row,
        SongsCompanion(
          durationSec: Value(length),
          enrichState: Value(row.userEdited ? row.enrichState : EnrichState.pending),
        ),
      );
      return length;
    } catch (e) {
      lastLengthUnreadable = e is! TdError && e is! TimeoutException && e is! SocketException;
      logEvent('metadata', '${s.title}: length not read (${e.runtimeType})', level: LogLevel.warning);
      return null;
    } finally {
      await progress?.cancel();
      if (!wasCached && !s.pinned) {
        final row = await _db.song(s.chatId, s.messageId);
        if (row != null && !row.pinned && !protectedIds.contains(row.uniqueId)) await _evict(row);
      }
    }
  }

  /// Reads a song's bit depth, sample rate and real codec once part of it is on
  /// this device. Costs no download of its own: it reads what playback fetched.
  Future<void> learnAudioDetails(Song s) async {
    if (s.sampleRate != null) return;
    try {
      final local = (await fileOf(s))['local'] as Json;
      final path = local['path'] as String? ?? '';
      if (path.isEmpty) return;
      final file = await File(path).open();
      try {
        final length = await file.length();
        final head = await file.read(_headerBytes);
        var header = parseAudioHeader(head);
        // MP4 files often keep what's needed at the end.
        if (header == null && local['is_downloading_completed'] == true && length > _headerBytes) {
          await file.setPosition(max(0, length - _tailBytes));
          header = parseAudioHeader(await file.read(_tailBytes));
        }
        if (header != null) {
          await _db.setAudioDetails(
            s.uniqueId,
            sampleRate: header.sampleRate,
            bitDepth: header.bitDepth,
            codec: header.codec,
          );
          logEvent('playback', '${s.title}: ${header.codec ?? ''} ${header.bitDepth ?? '?'}-bit ${header.sampleRate} Hz');
        }
      } finally {
        await file.close();
      }
    } catch (e) {
      logEvent('playback', '${s.title}: audio details not read (${e.runtimeType})', level: LogLevel.warning);
    }
  }

  static const _headerBytes = 256 * 1024, _tailBytes = 2 * 1024 * 1024;

  /// Where the part of a song downloaded so far is on this device; null if none yet.
  Future<String?> localPath(Song s) async {
    try {
      final path = ((await fileOf(s))['local'] as Json)['path'] as String? ?? '';
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  /// The tags and cover inside a song's file, once some of it is on this device. Null if
  /// they can't be read: a file only partly downloaded may not have them yet.
  Future<({EmbeddedTags tags, Uint8List? cover})?> embeddedTags(Song s) async {
    try {
      final local = (await fileOf(s))['local'] as Json;
      final path = local['path'] as String? ?? '';
      if (path.isEmpty) return null;
      final m = readMetadata(File(path), getImage: true);
      return (
        tags: EmbeddedTags(
          title: m.title,
          artist: m.artist,
          album: m.album,
          year: m.year?.year,
          genre: m.genres.firstOrNull,
        ),
        cover: m.pictures.firstOrNull?.bytes,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setPinned(Song s, bool pinned) async {
    await _db.updateSong(s, SongsCompanion(pinned: Value(pinned)));
    if (pinned) {
      await _download(s);
    } else {
      await enforce();
    }
  }

  Future<void> _download(Song s) async {
    final (file, bot) = await fileAndBot(s);
    await bot.call({
      '@type': 'downloadFile',
      'file_id': file['id'],
      'priority': 1,
      'offset': 0,
      'limit': 0,
      'synchronous': false,
    });
  }

  /// Starts fetching a song the player will want next, at low priority, so it is ready when
  /// the current one ends and TDLib can then go quiet. Nothing if it is already here.
  Future<void> prefetch(Song s) async {
    try {
      final row = await _db.song(s.chatId, s.messageId);
      if (row == null || row.cachedBytes >= row.size * 0.98 && row.size > 0) return;
      await _download(row);
    } on Object {
      // Offline or gone: it is fetched when it starts playing, as before.
    }
  }

  /// Restarts unfinished pinned downloads.
  Future<void> resumePins() async {
    for (final s in await _db.incompletePins()) {
      try {
        await _download(s);
      } on TdError {
        // Offline or deleted; picked up on next launch.
      }
    }
  }

  /// Stops downloading a song the user moved away from. Partial bytes stay.
  // A song seeked past leaves holes and never completes unless replayed
  // through them; add a low-priority fill pass if offline replay misses matter.
  Future<void> cancelIfNotPinned(Song s) async {
    final row = await _db.song(s.chatId, s.messageId);
    if (row == null || row.pinned) return;
    try {
      await _td.call({
        '@type': 'cancelDownloadFile',
        'file_id': await _fileId(row),
        'only_if_pending': false,
      });
    } on TdError {
      // Nothing to cancel.
    }
  }

  Future<void> clear() => enforce(limit: 0);

  Future<void> removeChatFiles(int chatId, {void Function(int done, int total)? onProgress}) async {
    final songs = await _db.cachedSongsIn(chatId);
    for (final (i, s) in songs.indexed) {
      await _evict(s);
      onProgress?.call(i + 1, songs.length);
    }
  }
}
