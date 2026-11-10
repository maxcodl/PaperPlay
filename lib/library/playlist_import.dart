import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../metadata/enricher.dart';
import 'audio_info.dart';
import 'db.dart';

/// A track listed by a streaming service: only its details, never its audio.
class ImportedTrack {
  const ImportedTrack(this.key, this.title, this.artist, this.durationSec, [this.addedAtMs]);

  /// When it was added to the playlist, if the source says (milliseconds since epoch).
  final int? addedAtMs;

  /// The service's id for the track, such as `spotify:track:…`.
  final String key;
  final String title, artist;
  final int durationSec;
}

class ImportError implements Exception {
  const ImportError(this.message);
  final String message;
  @override
  String toString() => message;
}

final _spotifyPlaylist = RegExp(r'(?:open\.spotify\.com/(?:[\w-]+/)?playlist/|spotify:playlist:)([A-Za-z0-9]{22})');

/// The playlist id in a Spotify link, or null if it isn't one.
String? spotifyPlaylistId(String link) => _spotifyPlaylist.firstMatch(link)?.group(1);

/// Reads a public playlist from Spotify's embed page, which needs no account.
///
/// This isn't an official API: Spotify can change the page or limit how many
/// tracks it lists, so a failure here must never touch what's already imported.
Future<({String name, List<ImportedTrack> tracks})> fetchSpotifyPlaylist(String id, http.Client client) async {
  final response = await client.get(
    Uri.parse('https://open.spotify.com/embed/playlist/$id'),
    headers: const {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/130 Safari/537.36'},
  );
  if (response.statusCode == 404) {
    throw const ImportError('Spotify can\'t find that playlist. It may be private.');
  }
  if (response.statusCode != 200) {
    throw ImportError('Spotify answered with error ${response.statusCode}.');
  }
  return parseSpotifyEmbed(utf8.decode(response.bodyBytes, allowMalformed: true));
}

/// Pulls the playlist out of the embed page's HTML.
({String name, List<ImportedTrack> tracks}) parseSpotifyEmbed(String html) {
  final data = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(html);
  if (data == null) throw const ImportError('Spotify\'s page has changed, so this link can\'t be read.');
  final Object? json;
  try {
    json = jsonDecode(data.group(1)!);
  } on FormatException {
    throw const ImportError('Spotify\'s page has changed, so this link can\'t be read.');
  }
  final list = _find(json, 'trackList');
  if (list is! List || list.isEmpty) throw const ImportError('That playlist is empty or private.');
  final tracks = <ImportedTrack>[];
  for (final t in list) {
    if (t is! Map) continue;
    final uri = t['uri'], title = t['title'];
    if (uri is! String || title is! String) continue;
    // The page separates artists with a non-breaking space.
    final artist = (t['subtitle'] as String? ?? '').replaceAll(' ', ' ').trim();
    final ms = t['duration'];
    tracks.add(ImportedTrack(uri, title, artist, ms is int ? (ms / 1000).round() : 0));
  }
  final name = _find(json, 'name');
  return (name: name is String && name.isNotEmpty ? name : 'Imported playlist', tracks: tracks);
}

Object? _find(Object? node, String key) {
  if (node is Map) {
    if (node.containsKey(key)) return node[key];
    for (final v in node.values) {
      final r = _find(v, key);
      if (r != null) return r;
    }
  } else if (node is List) {
    for (final v in node) {
      final r = _find(v, key);
      if (r != null) return r;
    }
  }
  return null;
}

final _credit = RegExp(r'(?:[\[(]|\s[-–]\s|\s)(?:feat|ft|featuring)\b\.?\s*([^\])]*)[\])]?', caseSensitive: false);

/// Title with featured-artist credits and remaster/version tags removed, so one song
/// from different releases gets one key.
String looseTitleKey(String title, String artist) {
  var t = cleanTitle(title, artist);
  t = t
      .replaceAll(RegExp(r'\s*[\[(][^\])]*remaster[^\])]*[\])]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+[-–]\s+[^-–]*remaster.*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*[\[(](?:mono|stereo|single version|album version|radio edit)[\])]', caseSensitive: false), '')
      .replaceAll(_credit, '');
  return comparableText(searchTitle(t));
}

String _titleKey(String title, String artist) => looseTitleKey(title, artist);

List<String> _artists(String artist) => artist
    .split(RegExp(r'\s*(?:,|&|\bfeat\.?\s|\bft\.?\s)\s*', caseSensitive: false))
    .map(comparableText)
    .where((a) => a.isNotEmpty)
    .toList();

/// Artists credited on a track: its artist field plus any "feat." names in the title.
List<String> _credited(String title, String artist) =>
    [..._artists(artist), for (final m in _credit.allMatches(title)) ..._artists(m.group(1) ?? '')];

/// How sure a library song is the same recording as a wanted track.
enum MatchKind { sure, maybe }

/// Same song if the loose title agrees and an artist is shared. With lengths known and
/// within 8 s that is [MatchKind.sure]; a different or unknown length is only
/// [MatchKind.maybe], for the owner to confirm.
MatchKind? matchKind(Song s, String title, String artist, int durationSec) {
  final key = _titleKey(title, artist);
  if (key.isEmpty || _titleKey(s.title, s.artist) != key) return null;
  final mine = _credited(s.title, s.artist), theirs = _credited(title, artist);
  if (!theirs.any((a) => mine.any((b) => b.contains(a) || a.contains(b)))) return null;
  final known = s.durationSec > 0 && durationSec > 0;
  return known && (s.durationSec - durationSec).abs() <= 8 ? MatchKind.sure : MatchKind.maybe;
}

bool matchesTrack(Song s, String title, String artist, int durationSec) =>
    matchKind(s, title, artist, durationSec) == MatchKind.sure;

/// Songs that might be [title] but can't be told for sure, closest length first.
List<Song> maybeMatches(Iterable<Song> songs, String title, String artist, int durationSec) =>
    [for (final s in songs) if (matchKind(s, title, artist, durationSec) == MatchKind.maybe) s]
      ..sort((a, b) => (a.durationSec - durationSec).abs().compareTo((b.durationSec - durationSec).abs()));

/// Review list: waiting tracks of [tracks] with the songs that might be them.
Future<Map<String, List<Song>>> reviewCandidates(AppDb db, Iterable<MissingTrack> tracks) async {
  final byTitle = <String, List<Song>>{};
  for (final s in await db.select(db.songs).get()) {
    (byTitle[_titleKey(s.title, s.artist)] ??= []).add(s);
  }
  return {
    for (final t in tracks)
      t.trackKey: maybeMatches(byTitle[_titleKey(t.title, t.artist)] ?? const [], t.title, t.artist, t.durationSec),
  };
}

/// The owner confirmed [song] is [track]: it joins the playlist and stops waiting.
Future<void> acceptMatch(AppDb db, MissingTrack track, Song song) async {
  await db.transaction(() async {
    await db.into(db.playlistSongs).insertOnConflictUpdate(
          PlaylistSongsCompanion.insert(
            playlistId: track.playlistId,
            chatId: song.chatId,
            messageId: song.messageId,
            addedAt: DateTime.now().millisecondsSinceEpoch + track.position,
            sourceAddedAt: Value(track.sourceAddedAt),
            removedAt: const Value(null),
          ),
        );
    await (db.delete(db.missingTracks)
          ..where((r) => r.playlistId.equals(track.playlistId) & r.trackKey.equals(track.trackKey)))
        .go();
  });
  db.announceChange();
}

bool _isLossless(Song s) => isLossless(audioFormat(s.mime, s.fileName));

/// The best copy of a track: lossless first, then the largest file.
Song? bestMatch(Iterable<Song> songs, String title, String artist, int durationSec) {
  Song? best;
  for (final s in songs) {
    if (!matchesTrack(s, title, artist, durationSec)) continue;
    if (best == null || _better(s, best)) best = s;
  }
  return best;
}

bool _better(Song a, Song b) {
  final al = _isLossless(a), bl = _isLossless(b);
  return al != bl ? al : a.size > b.size;
}

class ImportResult {
  const ImportResult(this.playlistId, this.name, this.matched, this.missing, {this.limited = false});
  final int playlistId;
  final String name;
  final int matched, missing;

  /// It came from the public page and reached that page's limit, so there may be more.
  final bool limited;
}

/// How many tracks Spotify's public embed page lists, however long the playlist is.
const _embedLimit = 100;

/// Creates or refreshes the playlist for [link]. Tracks already in the library
/// join it; the rest wait in its missing list until a matching song appears.
// chisle: a refresh only adds. Tracks removed at the source stay; add removal
// if the source keeps being the truth in practice.
///
/// [official] reads the whole list through the owner's Spotify login, when it can.
Future<ImportResult> importPlaylist(
  AppDb db,
  String link,
  http.Client client, {
  Future<({String name, List<ImportedTrack> tracks})?> Function(String id)? official,
}) async {
  final id = spotifyPlaylistId(link);
  if (id == null) throw const ImportError('That isn\'t a Spotify playlist link.');
  final whole = await official?.call(id);
  final source = whole ?? await fetchSpotifyPlaylist(id, client);
  final sourceUrl = 'https://open.spotify.com/playlist/$id';

  final existing = (await db.select(db.playlists).get())
      .where((p) => p.sourceUrl == sourceUrl && p.deletedAt == null)
      .firstOrNull;
  final playlistId = existing?.id ?? await db.createPlaylist(source.name, sourceUrl: sourceUrl);

  final known = {
    for (final m in await (db.select(db.missingTracks)..where((t) => t.playlistId.equals(playlistId))).get())
      m.trackKey,
  };
  await db.transaction(() async {
    for (final (i, t) in source.tracks.indexed) {
      // add() is false for a repeat: playlists can list one track twice.
      if (!known.add(t.key)) {
        if (t.addedAtMs != null) {
          await (db.update(db.missingTracks)
                ..where((r) => r.playlistId.equals(playlistId) & r.trackKey.equals(t.key)))
              .write(MissingTracksCompanion(sourceAddedAt: Value(t.addedAtMs)));
        }
        continue;
      }
      await db.into(db.missingTracks).insert(
            MissingTracksCompanion.insert(
              playlistId: playlistId,
              trackKey: t.key,
              title: t.title,
              artist: t.artist,
              durationSec: Value(t.durationSec),
              position: Value(i),
              sourceAddedAt: Value(t.addedAtMs),
            ),
          );
    }
  });
  await reconcileImports(db);
  await stampSourceDates(db, playlistId, source.tracks);
  final missing = await (db.select(db.missingTracks)..where((t) => t.playlistId.equals(playlistId))).get();
  final distinct = {for (final t in source.tracks) t.key}.length;
  return ImportResult(
    playlistId,
    source.name,
    distinct - missing.length,
    missing.length,
    limited: whole == null && source.tracks.length >= _embedLimit,
  );
}

/// Records the source's added dates on songs already in the playlist. Run on every
/// refresh, so playlists imported before dates were kept get them too.
Future<void> stampSourceDates(AppDb db, int playlistId, List<ImportedTrack> tracks) async {
  final dated = tracks.where((t) => t.addedAtMs != null).toList();
  if (dated.isEmpty) return;
  final entries = await (db.select(db.playlistSongs)
        ..where((r) => r.playlistId.equals(playlistId) & r.removedAt.isNull()))
      .get();
  final songs = {for (final s in await db.select(db.songs).get()) (s.chatId, s.messageId): s};
  final byTitle = <String, List<PlaylistSong>>{};
  for (final e in entries) {
    final s = songs[(e.chatId, e.messageId)];
    if (s != null) (byTitle[_titleKey(s.title, s.artist)] ??= []).add(e);
  }
  var changed = false;
  await db.transaction(() async {
    for (final t in dated) {
      for (final e in byTitle[_titleKey(t.title, t.artist)] ?? const <PlaylistSong>[]) {
        if (e.sourceAddedAt == t.addedAtMs || !matchesTrack(songs[(e.chatId, e.messageId)]!, t.title, t.artist, t.durationSec)) continue;
        await (db.update(db.playlistSongs)
              ..where((r) => r.playlistId.equals(playlistId) & r.chatId.equals(e.chatId) & r.messageId.equals(e.messageId)))
            .write(PlaylistSongsCompanion(sourceAddedAt: Value(t.addedAtMs)));
        changed = true;
      }
    }
  });
  if (changed) db.announceChange();
}

/// Matches waiting tracks against the library, and moves imported playlists to
/// a lossless copy when one has appeared. Run when songs are added or synced.
///
/// Only the playlist entry moves. The old file stays in Telegram: deleting it
/// automatically could lose the wrong song on a bad match.
Future<void> reconcileImports(AppDb db) async {
  final imported = (await db.livePlaylists()).where((p) => p.sourceUrl != null).toList();
  if (imported.isEmpty) return;
  final library = await db.select(db.songs).get();
  final byTitle = <String, List<Song>>{};
  for (final s in library) {
    (byTitle[_titleKey(s.title, s.artist)] ??= []).add(s);
  }
  List<Song> sameTitle(String title, String artist) => byTitle[_titleKey(title, artist)] ?? const [];

  var changed = false;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.transaction(() async {
    for (final p in imported) {
      final entries = await (db.select(db.playlistSongs)..where((r) => r.playlistId.equals(p.id))).get();
      final keys = {for (final e in entries) (e.chatId, e.messageId)};

      final waiting = await (db.select(db.missingTracks)..where((t) => t.playlistId.equals(p.id))).get();
      for (final t in waiting) {
        final song = bestMatch(sameTitle(t.title, t.artist), t.title, t.artist, t.durationSec);
        if (song == null) continue;
        // A song someone removed from this playlist stays removed.
        if (keys.add((song.chatId, song.messageId))) {
          await db.into(db.playlistSongs).insert(
                PlaylistSongsCompanion.insert(
                  playlistId: p.id,
                  chatId: song.chatId,
                  messageId: song.messageId,
                  addedAt: now + t.position,
                  sourceAddedAt: Value(t.sourceAddedAt),
                ),
              );
        }
        await (db.delete(db.missingTracks)
              ..where((r) => r.playlistId.equals(p.id) & r.trackKey.equals(t.trackKey)))
            .go();
        changed = true;
      }

      for (final e in entries.where((e) => e.removedAt == null)) {
        final song = library.where((s) => s.chatId == e.chatId && s.messageId == e.messageId).firstOrNull;
        if (song == null || _isLossless(song)) continue;
        final better = bestMatch(sameTitle(song.title, song.artist), song.title, song.artist, song.durationSec);
        if (better == null || !_isLossless(better)) continue;
        await (db.update(db.playlistSongs)
              ..where((r) =>
                  r.playlistId.equals(p.id) & r.chatId.equals(e.chatId) & r.messageId.equals(e.messageId)))
            .write(PlaylistSongsCompanion(removedAt: Value(now)));
        await db.into(db.playlistSongs).insertOnConflictUpdate(
              PlaylistSongsCompanion.insert(
                playlistId: p.id,
                chatId: better.chatId,
                messageId: better.messageId,
                addedAt: e.addedAt,
                removedAt: const Value(null),
              ),
            );
        changed = true;
      }
    }
  });
  if (changed) db.announceChange();
}
