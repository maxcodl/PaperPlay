import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../library/album_art.dart';
import '../library/db.dart';
import '../library/scanner.dart';
import '../log.dart';
import '../telegram/td_client.dart';
import 'cover_sources.dart';
import '../pace.dart';

/// MusicBrainz asks clients to identify themselves with contact info.
const _contact = String.fromEnvironment('CONTACT_URL');
const _userAgent = 'PaperPlay/0.1.0${_contact == '' ? '' : ' ( $_contact )'}';
const _headers = {'User-Agent': _userAgent};

class MbMatch {
  const MbMatch({
    required this.score,
    required this.title,
    required this.artist,
    required this.album,
    required this.releaseId,
    required this.lengthSec,
    this.year,
  });

  factory MbMatch.fromJson(Json r) {
    final releases = (r['releases'] as List? ?? const []).cast<Json>();
    final credits = (r['artist-credit'] as List? ?? const []).cast<Json>();
    return MbMatch(
      score: r['score'] as int? ?? 0,
      title: r['title'] as String? ?? '',
      artist: credits.map((c) => '${c['name']}${c['joinphrase'] ?? ''}').join(),
      album: releases.isEmpty ? '' : releases.first['title'] as String? ?? '',
      releaseId: releases.isEmpty ? null : releases.first['id'] as String?,
      lengthSec: r['length'] == null ? null : (r['length'] as int) ~/ 1000,
      year: _yearOf(r['first-release-date'] as String?),
    );
  }

  final int score;
  final String title, artist, album;
  final String? releaseId;
  final int? lengthSec, year;
}

int? _yearOf(String? date) => date == null || date.length < 4 ? null : int.tryParse(date.substring(0, 4));

/// A track from Deezer or iTunes, used when MusicBrainz has no match.
class ExternalMatch {
  const ExternalMatch({
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    required this.lengthSec,
    this.coverUrl,
    this.genre,
    this.year,
  });

  factory ExternalMatch.fromDeezer(Json r) {
    final album = r['album'] as Json? ?? const {};
    return ExternalMatch(
      source: 'Deezer',
      title: r['title'] as String? ?? '',
      artist: (r['artist'] as Json?)?['name'] as String? ?? '',
      album: album['title'] as String? ?? '',
      lengthSec: r['duration'] as int? ?? 0,
      coverUrl: album['cover_xl'] as String?,
    );
  }

  factory ExternalMatch.fromItunes(Json r) => ExternalMatch(
        source: 'iTunes',
        title: r['trackName'] as String? ?? '',
        artist: r['artistName'] as String? ?? '',
        album: r['collectionName'] as String? ?? '',
        lengthSec: (r['trackTimeMillis'] as int? ?? 0) ~/ 1000,
        coverUrl: (r['artworkUrl100'] as String?)?.replaceFirst('100x100bb', '600x600bb'),
        genre: r['primaryGenreName'] as String?,
        year: _yearOf(r['releaseDate'] as String?),
      );

  final String source, title, artist, album;
  final int lengthSec;
  final String? coverUrl, genre;
  final int? year;
}

/// Text reduced to lowercase letters and digits, for comparing names.
String comparableText(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

String _comparable(String s) => comparableText(s);

/// First result that's safely the same recording: the title and artist agree,
/// and the length is within 5 seconds. These services score nothing, so a
/// close search result alone isn't enough. A file with no length (many uploads carry none)
/// is matched on title and a known artist alone.
ExternalMatch? pickExternal(List<ExternalMatch> results, String title, String artist, int durationSec) {
  final wantTitle = _comparable(searchTitle(cleanTitle(title, artist)));
  final wantArtist = artist == 'Unknown artist' ? '' : _comparable(firstArtist(artist));
  if (wantTitle.isEmpty) return null;
  if (durationSec <= 0 && wantArtist.isEmpty) return null;
  for (final r in results) {
    if (durationSec > 0 && (r.lengthSec - durationSec).abs() > 5) continue;
    if (_comparable(searchTitle(r.title)) != wantTitle) continue;
    if (wantArtist.isEmpty || _comparable(r.artist).contains(wantArtist)) return r;
  }
  return null;
}

/// First match safe to apply without asking: score >= 90 and length within 5s.
MbMatch? pickMatch(List<MbMatch> matches, int durationSec) {
  if (durationSec <= 0) return null;
  for (final m in matches) {
    final length = m.lengthSec;
    if (m.score >= 90 && length != null && (length - durationSec).abs() <= 5) return m;
  }
  return null;
}

/// Wait before retrying a busy MusicBrainz: 4s, 8s, 16s, 32s, then 60s.
Duration busyDelay(int attempt) => Duration(seconds: min(60, 2 << attempt));

/// First name in `A, B & C`, since multi-artist strings rarely match exactly.
// Also splits names like "Tyler, The Creator"; "Edit tags" covers those.
String firstArtist(String artist) =>
    artist.split(RegExp(r'\s*(?:,|&|\bfeat\.?\s|\bft\.?\s)\s*', caseSensitive: false)).first.trim();

/// Removes junk that uploaders add: `1|5 - ` prefixes, `(FLAC)` tags, and the
/// artist repeated at either end. Also used as the title shown to the user.
String cleanTitle(String title, String artist) {
  var t = title
      .replaceFirst(RegExp(r'^\s*\d+\s*[|/]\s*\d+\s*-\s*'), '')
      .replaceAll(
        RegExp(r'\s*[\[(](?:flac|mp3|m4a|aac|wav|alac|hi-?res|lossless|\d+\s*kbps)[\])]',
            caseSensitive: false),
        '')
      .trim();
  final name = firstArtist(artist).toLowerCase();
  if (name.isNotEmpty) {
    final last = t.lastIndexOf(' - ');
    if (last > 0 && t.substring(last + 3).toLowerCase().startsWith(name)) {
      t = t.substring(0, last).trim();
    }
    final first = t.indexOf(' - ');
    if (first > 0 && t.substring(0, first).toLowerCase().startsWith(name)) {
      t = t.substring(first + 3).trim();
    }
  }
  return t.isEmpty ? title : t;
}

/// Title for searching: drops `(feat. X)`, `[Explicit]`, `(From "Y")` and
/// similar, which MusicBrainz usually stores differently. Keeps `(Remix)`.
String searchTitle(String title) {
  final t = title
      .replaceAll(
        RegExp(r'\s*[\[(](?:feat\.?|ft\.?|with |from |explicit|clean|official|lyric|audio|video|remaster)[^\])]*[\])]',
            caseSensitive: false),
        '')
      .trim();
  return t.isEmpty ? title : t;
}

class LrcLine {
  const LrcLine(this.time, this.text);
  final Duration time;
  final String text;
}

/// Parses `[mm:ss.xx] text` lines. Empty when [lrc] has no timestamps.
List<LrcLine> parseLrc(String lrc) {
  final stamp = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]');
  final lines = <LrcLine>[];
  for (final line in const LineSplitter().convert(lrc)) {
    final text = line.replaceAll(stamp, '').trim();
    for (final m in stamp.allMatches(line)) {
      final fraction = (m[3] ?? '0').padRight(3, '0').substring(0, 3);
      lines.add(LrcLine(
        Duration(
          minutes: int.parse(m[1]!),
          seconds: int.parse(m[2]!),
          milliseconds: int.parse(fraction),
        ),
        text,
      ));
    }
  }
  return lines..sort((a, b) => a.time.compareTo(b.time));
}

enum EnrichRun { idle, running, paused }

/// Works through [queue], newest first, until it's empty, including anything added
/// meanwhile. An item that fails or takes longer than [timeout] doesn't stop the rest.
Future<void> drainNewestFirst<T>(
  List<T> queue,
  Future<void> Function(T) work, {
  required Duration timeout,
  required void Function() onChange,
  required void Function(T, Object) onError,
  int workers = 1,
}) async {
  Future<void> one() async {
    while (queue.isNotEmpty) {
      final item = queue.removeLast();
      onChange();
      try {
        await work(item).timeout(timeout);
      } catch (e) {
        onError(item, e);
      }
    }
  }

  // Several at once: most of a cover's time is waiting on a server.
  await Future.wait([for (var i = 0; i < workers; i++) one()]);
}

enum CoverWork { none, first, upgrade }

/// What a song on screen still needs for its cover. A thumbnail with a full-size
/// source is upgraded right away, not only when the song is played. Covers someone
/// chose or edited are left alone.
CoverWork coverWorkFor(Song s) {
  if (s.coverPath == null) return CoverWork.first;
  final hasSource = s.releaseId != null || s.coverUrl != null;
  if (hasSource && !s.coverHiRes && s.coverAt == 0 && !s.userEdited) return CoverWork.upgrade;
  return CoverWork.none;
}

/// Plain words for a MusicBrainz search, without what its query language reads as syntax.
String musicBrainzQuery(String term) => term
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// A search result the owner can apply to a song, from any service.
class MetadataOption {
  const MetadataOption({
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    this.lengthSec,
    this.year,
    this.genre,
    this.releaseId,
    this.coverUrl,
  });

  factory MetadataOption.fromMusicBrainz(MbMatch m) => MetadataOption(
        source: 'MusicBrainz',
        title: m.title,
        artist: m.artist,
        album: m.album,
        lengthSec: m.lengthSec,
        year: m.year,
        releaseId: m.releaseId,
      );

  factory MetadataOption.fromExternal(ExternalMatch m) => MetadataOption(
        source: m.source,
        title: m.title,
        artist: m.artist,
        album: m.album,
        lengthSec: m.lengthSec,
        year: m.year,
        genre: m.genre,
        coverUrl: m.coverUrl,
      );

  final String source, title, artist, album;
  final int? lengthSec, year;
  final String? genre, releaseId, coverUrl;
}

/// A cover found online that the owner can choose.
class CoverOption {
  const CoverOption(this.url, this.label);
  final String url, label;
}

class Enricher {
  Enricher(this._td, this._db);

  final TdClient _td;
  final AppDb _db;
  final _http = http.Client();

  /// Whether metadata lookups are running, for the progress UI.
  final run = ValueNotifier(EnrichRun.idle);

  /// Covers waiting to load, for the progress UI.
  final coversQueued = ValueNotifier(0);

  /// The songs whose covers are waiting, for the Tasks page.
  List<Song> get queuedCovers => List.unmodifiable(_coverQueue);

  /// Covers asked for since the queue was last empty, so progress reads "left of total".
  final coversBatch = ValueNotifier(0);

  static const _retryAfter = Duration(minutes: 1);
  static const _maxBusyRetries = 6;
  Timer? _retry;

  /// MusicBrainz allows one request per second per IP.
  static const _mbInterval = Duration(milliseconds: 1100);

  static const _itunesInterval = Duration(seconds: 3, milliseconds: 500);
  var _lastItunes = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pause after each thumbnail fetched from Telegram.
  static const _maxQueuedCovers = 30;

  /// Nothing else limits a slow service or a Telegram download, and one that never
  /// answers would otherwise hold up every other cover for good.
  static const _coverTimeout = Duration(seconds: 60);
  final _coverQueue = <Song>[];
  final _coverTried = <String>{};
  final _upgradeTried = <String>{};
  var _coversRunning = false;

  var _stop = false;

  /// Ends the song-info run after the song being looked up. It starts again on the next
  /// scan or retry.
  void stop() {
    _stop = true;
    _retry?.cancel();
  }

  /// Processes pending songs one by one. Safe to call repeatedly. Stops on
  /// network failure; pending rows are retried on the next call.
  Future<void> kick() async {
    if (run.value == EnrichRun.running) return;
    _retry?.cancel();
    _stop = false;
    run.value = EnrichRun.running;
    var end = EnrichRun.paused;
    var busy = 0;
    try {
      while (true) {
        if (_stop) {
          end = EnrichRun.idle;
          return;
        }
        await gate();
        final song = await _nextOwned(_db.pendingToEnrich);
        if (song == null) {
          end = EnrichRun.idle;
          return;
        }
        try {
          await _enrich(song);
          busy = 0;
          await Future<void>.delayed(gap(Work.lookups));
        } on _MbUnavailable {
          // MusicBrainz often answers 503 for a moment, so retry the same song.
          busy++;
          if (busy > _maxBusyRetries) return;
          await Future<void>.delayed(busyDelay(busy));
        }
      }
    } on IOException {
      // Offline.
    } on http.ClientException {
      // Offline.
    } finally {
      run.value = end;
      if (end == EnrichRun.paused) _retry = Timer(_retryAfter, kick);
    }
  }

  /// Touches MusicBrainz only, never Telegram. Covers load on demand.
  Future<void> _enrich(Song song) async {
    if (song.userEdited) {
      await _db.updateSong(song, const SongsCompanion(enrichState: Value(EnrichState.done)));
      return;
    }
    // Deezer and iTunes are asked alongside MusicBrainz, so a miss there costs no extra wait.
    final externalSoon = _externalMatch(song);
    final match = pickMatch(await search(song.title, song.artist), song.durationSec);
    if (match != null) externalSoon.ignore();
    _coverTried.remove(song.uniqueId); // A match may offer a cover now.
    if (match != null) {
      await _db.updateSong(
        song,
        SongsCompanion(
          title: Value(match.title),
          artist: Value(match.artist),
          album: Value(match.album),
          releaseId: Value(match.releaseId),
          year: Value(match.year),
          metadataSource: const Value('MusicBrainz'),
          enrichState: const Value(EnrichState.done),
        ),
      );
      return;
    }
    final external = await externalSoon;
    if (external != null) {
      await _db.updateSong(
        song,
        SongsCompanion(
          title: Value(external.title),
          artist: Value(external.artist),
          album: Value(external.album),
          coverUrl: Value(external.coverUrl),
          genre: Value(external.genre),
          year: Value(external.year),
          metadataSource: Value(external.source),
          enrichState: const Value(EnrichState.done),
        ),
      );
      return;
    }
    await _db.updateSong(
      song,
      SongsCompanion(
        title: Value(cleanTitle(song.title, song.artist)),
        enrichState: const Value(EnrichState.noMatch),
      ),
    );
  }

  /// Tries Deezer, then iTunes. A failed service counts as no result, so one
  /// being down doesn't hold up the others.
  Future<ExternalMatch?> _externalMatch(Song s) async {
    final term = '${searchTitle(cleanTitle(s.title, s.artist))} ${firstArtist(s.artist)}';
    // Both asked at once; Deezer's answer still wins when both match.
    final both = await Future.wait([_deezer(term), _itunes(term)]);
    final first = pickExternal(both[0], s.title, s.artist, s.durationSec) ??
        pickExternal(both[1], s.title, s.artist, s.durationSec);
    if (first != null) return first;
    // Each country's iTunes catalogue holds songs the others don't.
    for (final country in extraStorefronts(s.title, s.artist)) {
      final found = pickExternal(await _itunes(term, country: country), s.title, s.artist, s.durationSec);
      if (found != null) return found;
    }
    return null;
  }

  Future<List<ExternalMatch>> _deezer(String term) async {
    final res = await _http.get(
      Uri.https('api.deezer.com', '/search', {'q': term, 'limit': '8'}),
      headers: _headers,
    );
    if (res.statusCode != 200) return const [];
    final Json body = jsonDecode(utf8.decode(res.bodyBytes));
    return (body['data'] as List? ?? const []).cast<Json>().map(ExternalMatch.fromDeezer).toList();
  }

  Future<List<ExternalMatch>> _itunes(String term, {String? country}) async {
    // iTunes allows about 20 searches a minute.
    final wait = _itunesInterval - DateTime.now().difference(_lastItunes);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastItunes = DateTime.now();
    final res = await _http.get(
      Uri.https('itunes.apple.com', '/search', {
        'term': term,
        'media': 'music',
        'entity': 'song',
        'limit': '8',
        'country': ?country,
      }),
      headers: _headers,
    );
    if (res.statusCode != 200) return const [];
    final Json body = jsonDecode(utf8.decode(res.bodyBytes));
    return (body['results'] as List? ?? const []).cast<Json>().map(ExternalMatch.fromItunes).toList();
  }

  var _moodScanning = false;

  /// Whether background lookups are allowed. Turning this off stops them.
  bool Function() moodLookupsAllowed = () => true;

  /// Waits until background work may run (see `Services.workGate`). Work the person is
  /// looking at, like a cover on screen, isn't held by it.
  Future<void> Function() gate = () async {};

  /// Whether this device is the one to look up a song. Linked devices split the library
  /// between them, so none repeats another's work. Set by the app.
  bool Function(String uniqueId) owns = (_) => true;

  /// The first song in [page] after [offset] that this device owns.
  Future<Song?> _nextOwned(Future<List<Song>> Function(int offset) page) async {
    for (var offset = 0;; offset += 100) {
      final rows = await page(offset);
      final mine = rows.where((s) => owns(s.uniqueId)).firstOrNull;
      if (mine != null) return mine;
      if (rows.length < 100) return null;
    }
  }
  Timer? _moodRetry;

  /// Looks up each song's lyrics and genre once, in the background, one at a time,
  /// so mixes have something to go on. Waits for metadata lookups to finish first.
  Future<void> scanMoods() async {
    if (_moodScanning) return;
    _moodScanning = true;
    _moodRetry?.cancel();
    try {
      while (true) {
        if (run.value == EnrichRun.running) {
          await Future<void>.delayed(const Duration(seconds: 10));
          continue;
        }
        if (!moodLookupsAllowed()) return;
        await gate();
        final song = await _nextOwned(_db.moodPending);
        if (song == null) return;
        await _scanMood(song);
        await Future<void>.delayed(gap(Work.lookups));
      }
    } on IOException {
      _moodRetry = Timer(const Duration(minutes: 5), scanMoods);
    } on http.ClientException {
      _moodRetry = Timer(const Duration(minutes: 5), scanMoods);
    } finally {
      _moodScanning = false;
    }
  }

  Future<void> _scanMood(Song s) async {
    var changes = SongsCompanion(moodScannedAt: Value(DateTime.now().millisecondsSinceEpoch));
    final artist = firstArtist(s.artist);
    final res = await _http.get(
      Uri.https('lrclib.net', '/api/search', {'track_name': s.title, 'artist_name': artist}),
      headers: _headers,
    );
    if (res.statusCode == 200 && s.lyrics == null) {
      final found = (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Json>();
      final words = found.map(_lyricsOf).whereType<String>().firstOrNull;
      if (words != null) {
        changes = changes.copyWith(lyrics: Value(words));
      } else if (found.any((r) => r['instrumental'] == true)) {
        changes = changes.copyWith(instrumental: const Value(true));
      }
    }
    if (s.genre == null) {
      final want = comparableText(searchTitle(cleanTitle(s.title, s.artist)));
      final results = await _itunes('${searchTitle(cleanTitle(s.title, s.artist))} $artist');
      // Only a genre comes from this, so it's enough that the title and artist agree.
      final match = results
          .where((r) => comparableText(searchTitle(r.title)) == want && comparableText(r.artist).contains(comparableText(artist)))
          .firstOrNull;
      if (match?.genre != null) changes = changes.copyWith(genre: Value(match!.genre));
    }
    await _db.updateSong(s, changes);
  }

  /// Asks for the cover of a song on screen. Keeps Telegram traffic tied to
  /// what the user is looking at, so a big library causes no background load.
  void requestCover(Song s) {
    if (coverWorkFor(s) == CoverWork.none || _gaveUpRecently(s) || !_coverTried.add(_coverKey(s))) return;
    _coverQueue.add(s);
    coversBatch.value++;
    if (_coverQueue.length > _maxQueuedCovers) {
      // Scrolled past long ago; it is requested again if it comes back.
      _coverTried.remove(_coverKey(_coverQueue.removeAt(0)));
      coversBatch.value--;
    }
    coversQueued.value = _coverQueue.length;
    _runCovers();
  }

  var _allCoversRunning = false;
  static const _noCoverKey = 'covers_none_found';

  /// Songs no source had a cover for, by file, with when that was last found out.
  Map<String, int>? _noCover;

  Future<Map<String, int>> _noCoverMap() async =>
      _noCover ??= (jsonDecode(await _db.pref(_noCoverKey) ?? '{}') as Map).cast<String, int>();

  bool _gaveUpRecently(Song s) {
    final at = _noCover?[s.uniqueId];
    return at != null &&
        DateTime.now().millisecondsSinceEpoch - at < const Duration(days: 7).inMilliseconds;
  }

  /// Queues every song still missing a cover (or with only a thumbnail to upgrade), so
  /// covers fill in in the background rather than only as songs come on screen. Songs on
  /// screen still jump the queue: it drains newest first.
  Future<void> coverAll() async {
    if (_allCoversRunning) return;
    _allCoversRunning = true;
    try {
      await gate();
      // Songs no source had a cover for are only tried again after a week, not every start.
      await _noCoverMap();
      for (final s in await _db.select(_db.songs).get()) {
        if (coverWorkFor(s) == CoverWork.none || _gaveUpRecently(s)) continue;
        // A phone with a PC connected leaves background covers to it; they sync across.
        if (!owns(s.uniqueId)) continue;
        if (!_coverTried.add(_coverKey(s))) continue;
        _coverQueue.add(s);
        coversBatch.value++;
      }
      coversQueued.value = _coverQueue.length;
      await _runCovers();
    } finally {
      _allCoversRunning = false;
    }
  }

  /// Gives songs with no match another go, for when a source that was out of reach works
  /// again, such as Deezer through a VPN. Songs someone edited are left alone. Returns how
  /// many were queued.
  /// Looks these songs up again: song info for any not edited by hand, and a fresh try
  /// for covers, even ones that found nothing last week. Returns how many were queued.
  Future<int> retrySongs(List<Song> songs) async {
    final failed = await _noCoverMap();
    var n = 0;
    for (final s in songs) {
      failed.remove(s.uniqueId);
      _coverTried.remove(_coverKey(s));
      if (!s.userEdited) {
        await (_db.update(_db.songs)..where((r) => r.chatId.equals(s.chatId) & r.messageId.equals(s.messageId)))
            .write(const SongsCompanion(enrichState: Value(EnrichState.pending)));
      }
      requestCover(s);
      n++;
    }
    await _db.setPref(_noCoverKey, jsonEncode(failed));
    unawaited(kick());
    return n;
  }

  Future<int> retryUnmatched() async {
    final queued = await (_db.update(_db.songs)
          ..where((s) => s.enrichState.equals(EnrichState.noMatch) & s.userEdited.equals(false)))
        .write(const SongsCompanion(enrichState: Value(EnrichState.pending)));
    resetCovers();
    unawaited(kick());
    return queued;
  }

  void resetCovers() {
    _coverQueue.clear();
    _coverTried.clear();
    coversQueued.value = 0;
    coversBatch.value = 0;
  }

  Future<void> _runCovers() async {
    if (_coversRunning) return;
    _coversRunning = true;
    try {
      await drainNewestFirst<Song>(
        _coverQueue,
        _coverWork,
        timeout: _coverTimeout,
        workers: 4,
        onChange: () => coversQueued.value = _coverQueue.length,
        onError: (song, error) {
          // Worth another try next time it's on screen. Anything else would fail the same way.
          if (error is IOException || error is http.ClientException) {
            _coverTried.remove(_coverKey(song));
          }
        },
      );
    } finally {
      _coversRunning = false;
      if (_coverQueue.isEmpty) coversBatch.value = 0;
    }
  }

  Future<void> _coverWork(Song queued) async {
    final song = await _db.song(queued.chatId, queued.messageId);
    if (song == null) return;
    // Counted as tried before it starts, so a crash, kill or odd failure can't make every start redo it.
    final tried = await _noCoverMap();
    tried[song.uniqueId] = DateTime.now().millisecondsSinceEpoch;
    await _db.setPref(_noCoverKey, jsonEncode(tried));
    switch (coverWorkFor(song)) {
      case CoverWork.first:
        await _loadCover(song);
      case CoverWork.upgrade:
        final full = await _fullCover(song);
        if (full != null) await _useFullCover(song, full);
      case CoverWork.none:
        break;
    }
    final after = await _db.song(queued.chatId, queued.messageId);
    logEvent('covers',
        '${song.title}: ${coverWorkFor(song).name} -> ${after == null ? 'gone' : coverWorkFor(after).name} '
        '(path ${after?.coverPath != null}, hiRes ${after?.coverHiRes}, release ${after?.releaseId != null}, url ${after?.coverUrl != null})');
    if (after == null || coverWorkFor(after) == CoverWork.none) {
      tried.remove(queued.uniqueId);
      await _db.setPref(_noCoverKey, jsonEncode(tried));
    }
  }

  /// A new source for a song's cover is worth another try, so it's in the key.
  String _coverKey(Song s) => '${s.uniqueId}:${s.releaseId}:${s.coverUrl}';

  /// Replaces a thumbnail, whose file nothing else uses.
  Future<void> _useFullCover(Song s, String full) async {
    await _db.updateSong(s, SongsCompanion(coverPath: Value(full), coverHiRes: const Value(true)));
    final old = s.coverPath;
    if (old != null && old != full) _deleteLater(old);
  }

  /// Screens may hold the old path for a moment, and a missing file would show as a blank.
  void _deleteLater(String path) => Timer(const Duration(seconds: 10), () async {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Already gone.
        }
      });

  /// With a known source, the full cover first: it saves a call to Telegram. Then
  /// the Telegram thumbnail, then a search of Deezer and iTunes.
  Future<void> _loadCover(Song s) async {
    if (s.releaseId != null || s.coverUrl != null) {
      final full = await _fullCover(s);
      if (full != null) return _useFullCover(s, full);
    }
    final thumb = await _thumbnailFile(s);
    if (thumb != null) {
      final small = await _downloadThumbnail(s, thumb);
      await Future<void>.delayed(gap(Work.covers));
      if (small != null) {
        await _db.updateSong(s, SongsCompanion(coverPath: Value(small)));
        return;
      }
    }
    final full = await _fullCover(s);
    if (full != null) {
      await _db.updateSong(s, SongsCompanion(coverPath: Value(full), coverHiRes: const Value(true)));
    }
  }

  Future<String?> _fullCover(Song s) async =>
      await _archiveCover(s, s.releaseId) ??
      await _urlCover(s, s.coverUrl ?? (await _externalMatch(s))?.coverUrl);

  /// Replaces a small Telegram thumbnail with a full-size cover when a song
  /// plays, since the player shows it large. Falls back to the thumbnail.
  Future<void> upgradeCover(Song s) async {
    if (s.coverHiRes || s.coverAt > 0 || s.userEdited || !_upgradeTried.add(s.uniqueId)) return;
    try {
      final row = await _db.song(s.chatId, s.messageId);
      if (row == null || row.coverHiRes) return;
      final full = await _fullCover(row);
      if (full != null) await _useFullCover(row, full);
    } on IOException {
      _upgradeTried.remove(s.uniqueId);
    } on http.ClientException {
      _upgradeTried.remove(s.uniqueId);
    }
  }

  /// Candidates from MusicBrainz, best first. Also backs the manual picker.
  Future<List<MbMatch>> search(String title, String artist) async {
    String quoted(String s) => '"${s.replaceAll(RegExp(r'["\\]'), ' ')}"';
    final recording = quoted(searchTitle(cleanTitle(title, artist)));
    final query = artist == 'Unknown artist'
        ? 'recording:$recording'
        : 'recording:$recording AND artist:${quoted(firstArtist(artist))}';
    final res = await _http.get(
      Uri.https('musicbrainz.org', '/ws/2/recording', {'query': query, 'fmt': 'json', 'limit': '8'}),
      headers: _headers,
    );
    if (res.statusCode == 503 || res.statusCode == 429) throw _MbUnavailable();
    if (res.statusCode != 200) return const [];
    final Json body = jsonDecode(utf8.decode(res.bodyBytes));
    return (body['recordings'] as List? ?? const []).cast<Json>().map(MbMatch.fromJson).toList();
  }

  /// Searches every service for whatever someone typed. A service that fails just
  /// adds nothing. Exact matches on length come first when [durationSec] is known.
  Future<List<MetadataOption>> searchOnline(String term, {int durationSec = 0}) async {
    final words = musicBrainzQuery(term);
    if (words.isEmpty) return const [];
    Future<List<MetadataOption>> safely(Future<List<MetadataOption>> Function() search) async {
      try {
        return await search();
      } on Exception {
        return const [];
      }
    }

    final results = await Future.wait([
      safely(() async {
        final res = await _http.get(
          Uri.https('musicbrainz.org', '/ws/2/recording', {'query': words, 'fmt': 'json', 'limit': '10'}),
          headers: _headers,
        );
        if (res.statusCode != 200) return const [];
        final Json body = jsonDecode(utf8.decode(res.bodyBytes));
        return (body['recordings'] as List? ?? const [])
            .cast<Json>()
            .map(MbMatch.fromJson)
            .map(MetadataOption.fromMusicBrainz)
            .toList();
      }),
      safely(() async => (await _deezer(term)).map(MetadataOption.fromExternal).toList()),
      safely(() async => (await _itunes(term)).map(MetadataOption.fromExternal).toList()),
    ]);
    final all = results.expand((r) => r).toList();
    if (durationSec > 0) {
      int gap(MetadataOption o) => o.lengthSec == null ? 9999 : (o.lengthSec! - durationSec).abs();
      // Stable, so within each service's own best-first order is kept.
      final indexed = all.indexed.toList()
        ..sort((a, b) {
          final byGap = (gap(a.$2) <= 5 ? 0 : 1).compareTo(gap(b.$2) <= 5 ? 0 : 1);
          return byGap != 0 ? byGap : a.$1.compareTo(b.$1);
        });
      return [for (final e in indexed) e.$2];
    }
    return all;
  }

  /// Applies a result someone chose; survives re-enrichment. Also takes its cover.
  /// Returns false if it has none, leaving the old one.
  Future<bool> applyOption(Song song, MetadataOption m) async {
    _coverTried.remove(_coverKey(song));
    await _db.updateSong(
      song,
      SongsCompanion(
        title: Value(m.title),
        artist: Value(m.artist),
        album: Value(m.album),
        releaseId: Value(m.releaseId),
        coverUrl: Value(m.coverUrl),
        year: Value(m.year),
        genre: m.genre == null ? const Value.absent() : Value(m.genre),
        metadataSource: Value(m.source),
        userEdited: const Value(true),
        enrichState: const Value(EnrichState.done),
      ),
    );
    final String? path;
    try {
      path = await _archiveCover(song, m.releaseId) ?? await _urlCover(song, m.coverUrl);
    } on IOException {
      return false;
    } on http.ClientException {
      return false;
    }
    if (path == null) return false;
    await _useChosenCover(song, path, DateTime.now().millisecondsSinceEpoch);
    return true;
  }

  /// Covers from Deezer and iTunes for a search. A failed service gives none.
  Future<List<CoverOption>> coverOptions(String term) async {
    final results = await Future.wait([
      for (final search in [_deezer, _itunes])
        search(term).catchError((Object _) => const <ExternalMatch>[]),
    ]);
    final seen = <String>{};
    return [
      for (final r in results.expand((list) => list))
        if (r.coverUrl != null && seen.add(r.coverUrl!))
          CoverOption(r.coverUrl!, [r.album, r.artist].where((t) => t.isNotEmpty).join(' · ')),
    ];
  }

  /// Sets a cover from [url] on [songs]. Returns false if it couldn't be downloaded.
  Future<bool> setCoverFromUrl(List<Song> songs, String url) async {
    final List<int> bytes;
    try {
      final res = await _http.get(Uri.parse(url), headers: _headers);
      if (res.statusCode != 200) return false;
      bytes = res.bodyBytes;
    } on IOException {
      return false;
    } on http.ClientException {
      return false;
    }
    await setCoverBytes(songs, bytes);
    return true;
  }

  /// Sets a cover from an image's bytes on [songs]. Each gets its own file, since
  /// a song's old cover file is deleted when it's replaced.
  Future<void> setCoverBytes(List<Song> songs, List<int> bytes) async {
    final at = DateTime.now().millisecondsSinceEpoch;
    for (final s in songs) {
      await saveChosenCover(s, bytes, at);
    }
  }

  /// Saves a chosen cover made at [at], here or on another device.
  Future<void> saveChosenCover(Song song, List<int> bytes, int at) async {
    final out = await _coverFile(song);
    await out.writeAsBytes(bytes);
    await _useChosenCover(song, out.path, at);
  }

  Future<void> _useChosenCover(Song song, String path, int at) async {
    final old = (await _db.song(song.chatId, song.messageId))?.coverPath;
    await _db.updateSong(
      song,
      SongsCompanion(coverPath: Value(path), coverHiRes: const Value(true), coverAt: Value(at)),
    );
    // Each cover has its own name, so nothing else can be using the old file.
    if (old != null && old != path) _deleteLater(old);
  }

  Future<File> _coverFile(Song s) async {
    final dir = await getApplicationSupportDirectory();
    final covers = await Directory(p.join(dir.path, 'covers')).create(recursive: true);
    // A new name each save: images are cached by path, so overwriting a cover
    // wouldn't show until the next launch.
    return File(p.join(covers.path, '${s.uniqueId}_${DateTime.now().millisecondsSinceEpoch}.jpg'));
  }

  /// The song's thumbnail file; served from TDLib's local message database.
  Future<Json?> _thumbnailFile(Song s) async {
    try {
      final message = await _td.call({
        '@type': 'getMessage',
        'chat_id': s.chatId,
        'message_id': s.messageId,
      });
      final payload = audioPayload(message);
      final thumb = payload == null ? null : payloadThumbnail(payload);
      return thumb?['file'] as Json?;
    } on TdError {
      return null;
    }
  }

  Future<String?> _downloadThumbnail(Song s, Json thumb) async {
    try {
      final file = await _td.call({
        '@type': 'downloadFile',
        'file_id': thumb['id'],
        'priority': 1,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      });
      final local = file['local'] as Json;
      if (local['is_downloading_completed'] != true) return null;
      final out = await File(local['path'] as String).copy((await _coverFile(s)).path);
      return out.path;
    } on TdError {
      return null;
    }
  }

  Future<String?> _archiveCover(Song s, String? releaseId) async {
    if (releaseId == null) return null;
    final own = await _saveCover(s, Uri.https('coverartarchive.org', '/release/$releaseId/front-500'));
    if (own != null) return own;
    // This release has no art, but another release of the same album may.
    final group = await _releaseGroupOf(releaseId);
    if (group == null) return null;
    return _saveCover(s, Uri.https('coverartarchive.org', '/release-group/$group/front-500'));
  }

  final _groups = <String, String?>{};
  var _lastMbLookup = DateTime.fromMillisecondsSinceEpoch(0);

  /// The album behind a release, asked of MusicBrainz at its pace and remembered, since a
  /// whole album's songs share it.
  Future<String?> _releaseGroupOf(String releaseId) async {
    if (_groups.containsKey(releaseId)) return _groups[releaseId];
    final wait = _mbInterval - DateTime.now().difference(_lastMbLookup);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _lastMbLookup = DateTime.now();
    final res = await _http.get(
      Uri.https('musicbrainz.org', '/ws/2/release/$releaseId', {'inc': 'release-groups', 'fmt': 'json'}),
      headers: _headers,
    );
    // A busy answer isn't remembered, so it's asked again next time.
    if (res.statusCode != 200) return null;
    return _groups[releaseId] = releaseGroupOf(jsonDecode(utf8.decode(res.bodyBytes)) as Json);
  }

  Future<String?> _urlCover(Song s, String? url) async => url == null ? null : _saveCover(s, Uri.parse(url));

  Future<String?> _saveCover(Song s, Uri uri) async {
    final bytes = await fetchWithRetry(
      _http,
      uri,
      headers: _headers,
      onFailure: (status) => logEvent(
        'covers',
        '${s.title}: ${uri.host} answered $status',
        level: status >= 500 ? LogLevel.warning : LogLevel.info,
      ),
    );
    if (bytes == null) return null;
    final out = await _coverFile(s);
    await out.writeAsBytes(bytes);
    logEvent('covers', '${s.title}: saved from ${uri.host}');
    return out.path;
  }

  static const _embeddedCoverLimit = 1536 * 1024;

  /// What the song's own file knows, for the gaps the online lookups left. The cover only
  /// fills in when there's no full-size one yet, and a person's choices are never touched.
  Future<void> useEmbedded(Song song, EmbeddedTags tags, Uint8List? cover) async {
    final row = await _db.song(song.chatId, song.messageId);
    if (row == null) return;
    final fill = fillFromTags(row, tags);
    if (fill != null) {
      await _db.updateSong(row, fill);
      logEvent('metadata', '${row.title}: filled from the file\'s own tags');
    }
    if (cover == null || row.coverAt > 0 || row.coverHiRes || row.userEdited) return;
    final bytes = cover.length <= _embeddedCoverLimit
        ? cover
        : (await shrinkCoverInBackground(cover, side: 1000, limit: _embeddedCoverLimit))?.bytes;
    if (bytes == null) return;
    final out = await _coverFile(row);
    await out.writeAsBytes(bytes);
    await _db.updateSong(row, SongsCompanion(coverPath: Value(out.path), coverHiRes: const Value(true)));
    final old = row.coverPath;
    if (old != null) _deleteLater(old);
    logEvent('covers', '${row.title}: cover taken from the file');
  }

  /// Lyrics for [s], from the DB or LRCLIB; stored once found. Null when none.
  Future<String?> lyrics(Song s) async {
    if (s.lyrics != null) return s.lyrics;
    final found = await _lrclibGet(s) ?? await _lrclibSearch(s);
    if (found != null) await _db.updateSong(s, SongsCompanion(lyrics: Value(found)));
    return found;
  }

  String? _lyricsOf(Json r) {
    final synced = r['syncedLyrics'] as String?;
    if (synced != null && synced.isNotEmpty) return synced;
    final plain = r['plainLyrics'] as String?;
    return plain == null || plain.isEmpty ? null : plain;
  }

  Future<String?> _lrclibGet(Song s) async {
    if (s.album.isEmpty || s.durationSec <= 0) return null;
    final res = await _http.get(
      Uri.https('lrclib.net', '/api/get', {
        'track_name': s.title,
        'artist_name': s.artist,
        'album_name': s.album,
        'duration': '${s.durationSec}',
      }),
      headers: _headers,
    );
    return res.statusCode == 200 ? _lyricsOf(jsonDecode(utf8.decode(res.bodyBytes)) as Json) : null;
  }

  Future<String?> _lrclibSearch(Song s) async {
    final res = await _http.get(
      Uri.https('lrclib.net', '/api/search', {'track_name': s.title, 'artist_name': s.artist}),
      headers: _headers,
    );
    if (res.statusCode != 200) return null;
    final rows = (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Json>();
    bool close(Json r) =>
        s.durationSec <= 0 || ((r['duration'] as num? ?? 0) - s.durationSec).abs() <= 5;
    for (final r in rows.where(close)) {
      final text = _lyricsOf(r);
      if (text != null) return text;
    }
    return null;
  }
}

class _MbUnavailable implements Exception {}
