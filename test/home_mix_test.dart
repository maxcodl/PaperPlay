import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/home_mix.dart';

Song _song(int id, {String? artist, String album = '', String? genre, int? played, String? cover}) => Song(
      chatId: 1,
      messageId: id,
      uniqueId: 'u$id',
      remoteId: 'r$id',
      title: 'Song $id',
      artist: artist ?? 'Artist ${id % 25}',
      album: album,
      durationSec: 200,
      size: 1,
      mime: 'audio/flac',
      fileName: 'f',
      date: 1000 - id,
      coverPath: cover ?? '/covers/$id.jpg',
      genre: genre,
      favorite: false,
      coverHiRes: false,
      userEdited: false,
      enrichState: 0,
      cachedBytes: 0,
      lastPlayedAt: played,
      pinned: false,
      tagsAt: 0,
      favoriteAt: 0,
      coverAt: 0,
      instrumental: false,
      moodScannedAt: 0,
      plays: 0,
      skips: 0,
    );

final _library = [
  for (var i = 0; i < 300; i++)
    _song(
      i,
      album: i % 3 == 0 ? 'Album ${i % 30}' : 'Single $i',
      genre: const ['Pop', 'Rock', 'Jazz'][i % 3],
      played: i < 20 ? 2000000000000 - i : (i < 40 ? 1000 : null),
    ),
];

HomeMix _mix(DateTime day) => buildHomeMix(
      songs: _library,
      recent: _library.take(20).toList(),
      favorites: _library.skip(50).take(15).toList(),
      day: day,
    );

Iterable<Song> _shown(HomeMix m) sync* {
  for (final t in m.tiles) {
    yield t.cover;
  }
  for (final s in m.shelves) {
    yield* s.songs;
    for (final g in s.groups) {
      yield g.cover;
    }
  }
}

void main() {
  final day = DateTime(2026, 11, 6);

  test('no song or cover appears twice anywhere on the page', () {
    final mix = _mix(day);
    final shown = _shown(mix).toList();
    expect(mix.shelves.length, greaterThanOrEqualTo(5));
    expect(shown.map((s) => s.uniqueId).toSet().length, shown.length);
    expect(shown.map((s) => s.coverPath).toSet().length, shown.length);
  });

  test('songs from one album count as a repeat, though each has its own cover file', () {
    final mix = _mix(day);
    final albums = _shown(mix).map((s) => s.album).where((a) => a.startsWith('Album')).toList();
    expect(albums.toSet().length, albums.length);
  });

  test('songs sharing a cover count as a repeat, and a row without enough is dropped', () {
    final sameCover = [for (var i = 0; i < 12; i++) _song(i, cover: '/one.jpg', artist: 'A')];
    final mix = buildHomeMix(songs: sameCover, recent: sameCover, favorites: const [], day: day);
    expect(mix.shelves, isEmpty, reason: 'twelve copies of one picture is not a row');
  });

  test('the page stays the same during a day and changes the next', () {
    List<String> ids(HomeMix m) => _shown(m).map((s) => s.uniqueId).toList();
    expect(ids(_mix(day)), ids(_mix(DateTime(2026, 11, 6, 23))));
    expect(ids(_mix(day)), isNot(ids(_mix(DateTime(2026, 11, 7)))));
  });

  test('single-song albums are never shown as albums', () {
    final albums = _mix(day).shelves.where((s) => s.kind == ShelfKind.albums).expand((s) => s.groups);
    expect(albums, isNotEmpty);
    expect(albums.every((g) => g.songs.length >= 2), isTrue);
    expect(albums.any((g) => g.name.startsWith('Single')), isFalse);
  });

  test('picks for today are songs not played yet, and tiles name whole collections', () {
    final mix = _mix(day);
    final picks = mix.shelves.firstWhere((s) => s.title == 'Picked for today').songs;
    expect(picks.every((s) => s.lastPlayedAt == null), isTrue);
    expect(mix.tiles, isNotEmpty);
    expect(mix.tiles.every((t) => t.title.endsWith(' mix') && t.songs.length >= 4), isTrue);
  });

  test('a tiny or empty library builds without failing', () {
    expect(buildHomeMix(songs: const [], recent: const [], favorites: const [], day: day).shelves, isEmpty);
    final two = [_song(1), _song(2)];
    expect(buildHomeMix(songs: two, recent: two, favorites: const [], day: day).shelves, isEmpty);
  });
}
