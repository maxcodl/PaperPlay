import 'dart:math';

import '../metadata/enricher.dart';
import 'db.dart';

enum ShelfKind { songs, albums, artists }

/// One row of the Home page. Albums and artists come with a cover to show that
/// no other row has used.
class MixShelf {
  const MixShelf(this.title, this.kind, this.songs, {this.groups = const []});
  final String title;
  final ShelfKind kind;

  /// The songs of a [ShelfKind.songs] row.
  final List<Song> songs;

  /// The albums or artists of the other kinds.
  final List<MixGroup> groups;
}

class MixGroup {
  const MixGroup(this.name, this.cover, this.songs);
  final String name;
  final Song cover;
  final List<Song> songs;
}

/// A generated collection for the quick tiles.
class MixTile {
  const MixTile(this.title, this.cover, this.songs);
  final String title;
  final Song cover;
  final List<Song> songs;
}

class HomeMix {
  const HomeMix(this.tiles, this.shelves);
  final List<MixTile> tiles;
  final List<MixShelf> shelves;
}

const _shelfMax = 12, _shelfMin = 4;
const _staleAfter = Duration(days: 30);

/// Plans the Home page so nothing repeats: a song, or any song sharing its cover,
/// appears at most once across every row. Variety comes from a shuffle seeded by
/// the [day], so the page stays put during a day and differs the next.
HomeMix buildHomeMix({
  required List<Song> songs,
  required List<Song> recent,
  required List<Song> favorites,
  required DateTime day,
  int tileCount = 6,
}) {
  final random = Random(day.year * 1000 + day.month * 40 + day.day);
  final seen = <String>{};
  // Songs on an album look the same on a shelf, even though each has its own file.
  String keyOf(Song s) => s.album.isNotEmpty ? 'album:${s.album}' : s.coverPath ?? s.uniqueId;
  List<T> shuffled<T>(Iterable<T> items) => items.toList()..shuffle(random);

  // Takes up to the maximum unseen songs. Claims them only if the row is worth
  // showing, so a row too short to appear doesn't use up songs.
  List<Song>? take(Iterable<Song> pool) {
    final picked = <Song>[];
    final keys = <String>{};
    for (final s in pool) {
      final key = keyOf(s);
      if (seen.contains(key) || !keys.add(key)) continue;
      picked.add(s);
      if (picked.length == _shelfMax) break;
    }
    if (picked.length < _shelfMin) return null;
    seen.addAll(keys);
    return picked;
  }

  Map<String, List<Song>> groupBy(String? Function(Song) keyFn) {
    final groups = <String, List<Song>>{};
    for (final s in songs) {
      final key = keyFn(s);
      if (key != null && key.isNotEmpty) (groups[key] ??= []).add(s);
    }
    return groups;
  }

  // Single-song "albums" would just repeat the song, so only real ones count.
  final albums = groupBy((s) => s.album)..removeWhere((_, list) => list.length < 2);
  final artists = groupBy((s) => firstArtist(s.artist));
  final genres = groupBy((s) => s.genre);

  // The first unused cover in a group, claimed for it.
  Song? coverFor(List<Song> list) {
    for (final s in list) {
      if (seen.add(keyOf(s))) return s;
    }
    return null;
  }

  final shelves = <MixShelf>[];
  void addSongs(String title, Iterable<Song> pool) {
    final picked = take(pool);
    if (picked != null) shelves.add(MixShelf(title, ShelfKind.songs, picked));
  }

  MixShelf? groupShelf(String title, ShelfKind kind, Iterable<MapEntry<String, List<Song>>> pool) {
    final picked = <MixGroup>[];
    for (final e in pool) {
      if (picked.length == _shelfMax) break;
      final cover = coverFor(e.value);
      if (cover != null) picked.add(MixGroup(e.key, cover, e.value));
    }
    return picked.length >= _shelfMin ? MixShelf(title, kind, const [], groups: picked) : null;
  }

  void addGroups(String title, ShelfKind kind, Iterable<MapEntry<String, List<Song>>> pool) {
    final shelf = groupShelf(title, kind, pool);
    if (shelf != null) shelves.add(shelf);
  }

  addSongs('Recently played', recent);

  // Chosen here, though shown further down: each album can only appear once on
  // the page, and rows of songs would otherwise use them all up first.
  final albumRow = groupShelf('Albums', ShelfKind.albums, shuffled(albums.entries));

  // Collections for the tiles, which name a whole group rather than one song.
  final tiles = <MixTile>[];
  final topGenres = genres.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
  final tilePool = [
    for (final g in shuffled(topGenres.where((g) => g.value.length >= _shelfMin).take(8)))
      ('${g.key} mix', shuffled(g.value)),
    for (final a in shuffled(artists.entries.where((a) => a.value.length >= _shelfMin)))
      ('${a.key} mix', shuffled(a.value)),
  ];
  for (final (title, list) in tilePool) {
    if (tiles.length == tileCount) break;
    final cover = coverFor(list);
    if (cover != null) tiles.add(MixTile(title, cover, list));
  }

  addSongs('Picked for today', shuffled(songs.where((s) => s.lastPlayedAt == null)));

  // What's been played lately decides what to suggest more of.
  final recentArtists = <String>{for (final s in recent) firstArtist(s.artist)};
  final suggested = recentArtists.where((a) => (artists[a]?.length ?? 0) >= _shelfMin).take(2);
  for (final a in suggested) {
    addSongs('More from $a', shuffled(artists[a]!));
  }

  if (albumRow != null) shelves.add(albumRow);
  addSongs('Recently added', songs);

  final recentGenres = <String>{
    for (final s in recent)
      if (s.genre != null) s.genre!,
  };
  final genre = recentGenres.where((g) => (genres[g]?.length ?? 0) >= _shelfMin).firstOrNull;
  if (genre != null) addSongs('More $genre', shuffled(genres[genre]!));

  addGroups(
    'Artists',
    ShelfKind.artists,
    shuffled(artists.entries.where((a) => a.value.length >= 2)),
  );
  addSongs('Your favorites', shuffled(favorites));

  final stale = day.subtract(_staleAfter).millisecondsSinceEpoch;
  addSongs(
    'Back in rotation',
    songs.where((s) => s.lastPlayedAt != null && s.lastPlayedAt! < stale).toList()
      ..sort((a, b) => a.lastPlayedAt!.compareTo(b.lastPlayedAt!)),
  );

  // Whatever hasn't appeared yet, so the page keeps offering something new.
  addSongs('More to explore', shuffled(songs));

  return HomeMix(tiles, shelves);
}
