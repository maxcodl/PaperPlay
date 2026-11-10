import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/playlist_import.dart';

String _page(List<Map<String, Object?>> tracks) => '<html><script id="__NEXT_DATA__" type="application/json">'
    '${jsonEncode({
      'props': {
        'pageProps': {
          'state': {
            'data': {
              'entity': {'name': 'My list', 'trackList': tracks},
            },
          },
        },
      },
    })}</script></html>';

Map<String, Object?> _track(String id, String title, String artist, int seconds) => {
      'uri': 'spotify:track:$id',
      'title': title,
      'subtitle': artist,
      'duration': seconds * 1000,
    };

http.Client _serving(String html) => MockClient((_) async => http.Response.bytes(utf8.encode(html), 200));

const _link = 'https://open.spotify.com/playlist/5Zvz5JZqysHQsDN9w97bkk?si=702158369d5c4490';

void main() {
  late AppDb db;
  setUp(() => db = AppDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> add(int id, String title, String artist, int seconds, {String mime = 'audio/mpeg', int size = 100}) =>
      db.into(db.songs).insert(
            SongsCompanion.insert(
              chatId: 1,
              messageId: id,
              uniqueId: 'u$id',
              remoteId: 'r$id',
              title: title,
              artist: artist,
              size: size,
              mime: mime,
              fileName: 'f',
              date: 0,
              durationSec: Value(seconds),
            ),
          );

  Song song(int id, String title, String artist, int seconds) => Song(
        chatId: 1,
        messageId: id,
        uniqueId: 'u$id',
        remoteId: 'r$id',
        title: title,
        artist: artist,
        album: '',
        durationSec: seconds,
        size: 1,
        mime: 'audio/mpeg',
        fileName: 'f',
        date: 0,
        favorite: false,
        coverHiRes: false,
        userEdited: false,
        enrichState: 0,
        cachedBytes: 0,
        pinned: false,
        tagsAt: 0,
        favoriteAt: 0,
        coverAt: 0,
        instrumental: false,
        moodScannedAt: 0,
        plays: 0,
        skips: 0,
      );

  test('a refresh stamps added dates on songs already in the playlist', () async {
    await add(1, 'Song', 'A', 200);
    final first = await importPlaylist(db, _link, _serving(_page([_track('t1', 'Song', 'A', 200)])));
    expect(await db.sourceDates(first.playlistId), isEmpty);
    await importPlaylist(
      db,
      _link,
      _serving(''),
      official: (_) async => (name: 'My list', tracks: [const ImportedTrack('spotify:track:t1', 'Song', 'A', 200, 5000)]),
    );
    expect(await db.sourceDates(first.playlistId), {'1:1': 5000});
  });

  group('loose matching', () {
    test('featured credits and remaster tags do not change the key', () {
      final k = looseTitleKey('Song', 'A');
      expect(looseTitleKey('Song (feat. B)', 'A'), k);
      expect(looseTitleKey('Song - feat. B', 'A'), k);
      expect(looseTitleKey('Song [ft. B]', 'A'), k);
      expect(looseTitleKey('Song - Remastered 2011', 'A'), k);
      expect(looseTitleKey('Song (2011 Remaster)', 'A'), k);
      expect(looseTitleKey('Song (Live)', 'A'), isNot(k));
    });

    test('another release of one song is sure; odd or unknown length is only maybe', () {
      expect(matchKind(song(1, 'Song - Remastered 2011', 'A', 203), 'Song (feat. B)', 'A', 200), MatchKind.sure);
      expect(matchKind(song(1, 'Song', 'A', 240), 'Song', 'A', 200), MatchKind.maybe);
      expect(matchKind(song(1, 'Song', 'A', 0), 'Song', 'A', 200), MatchKind.maybe);
      expect(matchKind(song(1, 'Song', 'Z', 200), 'Song', 'A', 200), isNull);
      expect(matchKind(song(1, 'Other', 'A', 200), 'Song', 'A', 200), isNull);
    });

    test('a featured artist in the title counts as credited', () {
      expect(matchKind(song(1, 'Song', 'B', 200), 'Song (feat. B)', 'A', 200), MatchKind.sure);
    });

    test('a maybe is not added by itself, only when accepted', () async {
      await add(1, 'Song', 'A', 245);
      await importPlaylist(db, _link, _serving(_page([_track('t1', 'Song', 'A', 200)])));
      expect(await db.select(db.playlistSongs).get(), isEmpty);
      final missing = await db.select(db.missingTracks).getSingle();
      final cands = await reviewCandidates(db, [missing]);
      expect(cands[missing.trackKey]!.single.messageId, 1);
      await acceptMatch(db, missing, cands[missing.trackKey]!.single);
      expect(await db.select(db.playlistSongs).get(), hasLength(1));
      expect(await db.select(db.missingTracks).get(), isEmpty);
    });
  });

  test('finds the id in the forms Spotify shares', () {
    expect(spotifyPlaylistId(_link), '5Zvz5JZqysHQsDN9w97bkk');
    expect(spotifyPlaylistId('https://open.spotify.com/intl-de/playlist/5Zvz5JZqysHQsDN9w97bkk'), isNotNull);
    expect(spotifyPlaylistId('spotify:playlist:5Zvz5JZqysHQsDN9w97bkk'), isNotNull);
    expect(spotifyPlaylistId('https://open.spotify.com/album/5Zvz5JZqysHQsDN9w97bkk'), isNull);
    expect(spotifyPlaylistId('hello'), isNull);
  });

  test('reads tracks from the embed page, cleaning its artist separator', () {
    final r = parseSpotifyEmbed(_page([_track('a', 'Apologize', 'Timbaland, OneRepublic', 184)]));
    expect(r.name, 'My list');
    expect(r.tracks.single.artist, 'Timbaland, OneRepublic');
    expect(r.tracks.single.durationSec, 184);
  });

  test('a changed page is a clear error, not a crash', () {
    expect(() => parseSpotifyEmbed('<html></html>'), throwsA(isA<ImportError>()));
    expect(() => parseSpotifyEmbed(_page([])), throwsA(isA<ImportError>()));
  });

  group('matching', () {
    test('accepts tags that differ in the usual ways', () {
      expect(matchesTrack(song(1, 'Sailor Song', 'Gigi Perez', 212), 'Sailor Song', 'Gigi Perez', 211), isTrue);
      expect(matchesTrack(song(1, 'Apologize (FLAC)', 'OneRepublic', 184), 'Apologize', 'Timbaland, OneRepublic', 184), isTrue);
      expect(matchesTrack(song(1, 'K. - Remaster', 'Cigarettes After Sex', 320), 'K. - Remaster', 'Cigarettes After Sex', 320), isTrue);
    });

    test('refuses a different length, artist or title', () {
      expect(matchesTrack(song(1, 'Hello', 'Adele', 295), 'Hello', 'Adele', 240), isFalse, reason: 'length');
      expect(matchesTrack(song(1, 'Hello', 'Lionel Richie', 295), 'Hello', 'Adele', 295), isFalse, reason: 'artist');
      expect(matchesTrack(song(1, 'Hello (Remix)', 'Adele', 295), 'Hello', 'Adele', 295), isFalse, reason: 'title');
    });

    test('an unknown length is never a match', () {
      expect(matchesTrack(song(1, 'Hello', 'Adele', 0), 'Hello', 'Adele', 295), isFalse);
    });
  });

  test('imports matched tracks and keeps the rest waiting', () async {
    await add(1, 'Sailor Song', 'Gigi Perez', 212);
    final page = _page([_track('a', 'Sailor Song', 'Gigi Perez', 211), _track('b', 'K.', 'Cigarettes After Sex', 320)]);
    final r = await importPlaylist(db, _link, _serving(page));
    expect([r.matched, r.missing], [1, 1]);
    expect((await db.watchPlaylistSongs(r.playlistId).first).single.title, 'Sailor Song');
    expect((await db.watchMissing(r.playlistId).first).single.title, 'K.');
  });

  test('a waiting track joins when its song appears, and then moves to a FLAC', () async {
    final page = _page([_track('b', 'K.', 'Cigarettes After Sex', 320)]);
    final r = await importPlaylist(db, _link, _serving(page));
    expect(r.missing, 1);

    await add(2, 'K.', 'Cigarettes After Sex', 320);
    await reconcileImports(db);
    expect((await db.watchPlaylistSongs(r.playlistId).first).single.messageId, 2);
    expect(await db.watchMissing(r.playlistId).first, isEmpty);

    await add(3, 'K.', 'Cigarettes After Sex', 320, mime: 'audio/flac', size: 900);
    await reconcileImports(db);
    expect((await db.watchPlaylistSongs(r.playlistId).first).single.messageId, 3);
    expect(await db.song(1, 2), isNotNull, reason: 'the old file stays');
  });

  test('a playlist listing one track twice imports it once', () async {
    final page = _page([_track('a', 'K.', 'Cigarettes After Sex', 320), _track('a', 'K.', 'Cigarettes After Sex', 320)]);
    final r = await importPlaylist(db, _link, _serving(page));
    expect([r.matched, r.missing], [0, 1]);
  });

  test('importing again refreshes the same playlist without duplicates', () async {
    await add(1, 'Sailor Song', 'Gigi Perez', 212);
    final first = _page([_track('a', 'Sailor Song', 'Gigi Perez', 212)]);
    final r1 = await importPlaylist(db, _link, _serving(first));
    final second = _page([_track('a', 'Sailor Song', 'Gigi Perez', 212), _track('b', 'K.', 'Cigarettes After Sex', 320)]);
    final r2 = await importPlaylist(db, _link, _serving(second));
    expect(r2.playlistId, r1.playlistId);
    expect((await db.livePlaylists()).length, 1);
    expect((await db.watchPlaylistSongs(r1.playlistId).first).length, 1);
    expect((await db.watchMissing(r1.playlistId).first).length, 1);
  });

  test('a song removed from an imported playlist stays removed', () async {
    await add(1, 'Sailor Song', 'Gigi Perez', 212);
    final page = _page([_track('a', 'Sailor Song', 'Gigi Perez', 212)]);
    final r = await importPlaylist(db, _link, _serving(page));
    await db.removeFromPlaylist(r.playlistId, (await db.song(1, 1))!);
    await importPlaylist(db, _link, _serving(page));
    expect(await db.watchPlaylistSongs(r.playlistId).first, isEmpty);
  });

  test('a failed fetch leaves the library alone', () async {
    final failing = MockClient((_) async => http.Response('', 500));
    await expectLater(importPlaylist(db, _link, failing), throwsA(isA<ImportError>()));
    expect(await db.livePlaylists(), isEmpty);
  });
}
