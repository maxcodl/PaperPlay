import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/neighbours.dart';

Song _song(int id, {String artist = 'A', String album = '', String? genre, int? year}) => Song(
      chatId: 1,
      messageId: id,
      uniqueId: 'u$id',
      remoteId: 'r$id',
      title: 'Song $id',
      artist: artist,
      album: album,
      durationSec: 200,
      size: 1,
      mime: 'audio/flac',
      fileName: 'f',
      date: 1000 - id,
      genre: genre,
      year: year,
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

void main() {
  test('songs sharing a playlist are neighbours, and a seed suggests them', () {
    final songs = [for (var i = 0; i < 10; i++) _song(i, artist: 'Artist $i')];
    final n = buildNeighbours(songs, [
      ['u0', 'u1', 'u2'],
      ['u5', 'u6'],
    ]);
    expect(n['u0'], containsAll(['u1', 'u2']));
    expect(n['u0'], isNot(contains('u5')));
    final byId = {for (final s in songs) s.uniqueId: s};
    final got = suggestFrom([songs[0]], n, byId);
    expect(got.map((s) => s.uniqueId), containsAll(['u1', 'u2']));
    expect(got.map((s) => s.uniqueId), isNot(contains('u0')), reason: 'never a seed');
  });

  test('at most perArtist from one artist, and excluded songs are skipped', () {
    final songs = [for (var i = 0; i < 8; i++) _song(i, artist: 'Same')];
    final byId = {for (final s in songs) s.uniqueId: s};
    final n = buildNeighbours(songs, const []);
    final got = suggestFrom([songs[0]], n, byId, exclude: {'u1'}, perArtist: 2);
    expect(got.length, 2);
    expect(got.map((s) => s.uniqueId), isNot(contains('u1')));
  });

  test('cost stays small for a large library', () {
    final songs = [for (var i = 0; i < 20000; i++) _song(i, artist: 'Artist ${i % 500}', album: 'Album ${i % 3000}', genre: 'Pop', year: 1990 + i % 30)];
    final sw = Stopwatch()..start();
    final n = buildNeighbours(songs, [
      [for (var i = 0; i < 300; i++) 'u$i'],
    ]);
    sw.stop();
    expect(n.length, greaterThan(15000));
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
