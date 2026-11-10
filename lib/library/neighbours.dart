import 'dart:math';

import '../metadata/enricher.dart';
import 'db.dart';

/// Light suggestions: for each song a short list of its closest songs, worked out once
/// from what the library already knows (playlists and topics it shares, artist, album,
/// genre and decade), never from audio. Cost is about songs x a few, not songs squared,
/// because a group only links each song to the few after it.
const _window = 6; // How many following songs of a group each song is linked to.
const _keep = 20; // Neighbours kept per song.
const _groupCap = 400; // A group larger than this says little about any pair.

/// Weights of the signals. A shared playlist says most; the rest fill in.
const _wGroup = 0.4, _wArtist = 0.25, _wAlbum = 0.25, _wGenre = 0.2;

/// [groups] are lists of unique ids that belong together (a playlist, a topic).
Map<String, List<String>> buildNeighbours(List<Song> songs, List<List<String>> groups) {
  final score = <String, Map<String, double>>{};
  void link(String a, String b, double w) {
    if (a == b) return;
    final m = score[a] ??= {};
    m[b] = (m[b] ?? 0) + w;
    final n = score[b] ??= {};
    n[a] = (n[a] ?? 0) + w;
  }

  void linkRun(List<String> ids, double w) {
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length && j <= i + _window; j++) {
        link(ids[i], ids[j], w);
      }
    }
  }

  for (final g in groups) {
    if (g.length > 1 && g.length <= _groupCap) linkRun(g, _wGroup);
  }

  List<String> ids(Iterable<Song> list) => [for (final s in list) s.uniqueId];
  void bucket(String? Function(Song) key, double w) {
    final by = <String, List<Song>>{};
    for (final s in songs) {
      final k = key(s);
      if (k != null && k.isNotEmpty) (by[k] ??= []).add(s);
    }
    for (final list in by.values) {
      if (list.length > 1) linkRun(ids(list), w);
    }
  }

  bucket((s) => firstArtist(s.artist).toLowerCase(), _wArtist);
  bucket((s) => s.album.isEmpty ? null : '${s.album.toLowerCase()}|${firstArtist(s.artist).toLowerCase()}', _wAlbum);
  bucket((s) => s.genre == null || s.year == null ? null : '${s.genre!.toLowerCase()}|${s.year! ~/ 10}', _wGenre);

  return {
    for (final e in score.entries)
      e.key: (e.value.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(_keep)
          .map((x) => x.key)
          .toList(),
  };
}

/// Songs to suggest from [seeds] (what was played or liked lately): the union of their
/// neighbours, ranked by how many seeds point at them, at most [perArtist] from one
/// artist, never a seed or an [exclude]d song.
List<Song> suggestFrom(
  Iterable<Song> seeds,
  Map<String, List<String>> neighbours,
  Map<String, Song> byId, {
  Set<String> exclude = const {},
  int limit = 12,
  int perArtist = 2,
}) {
  final seedList = seeds.toList();
  final seedIds = {for (final s in seedList) s.uniqueId};
  final votes = <String, double>{};
  for (final seed in seedList) {
    final list = neighbours[seed.uniqueId];
    if (list == null) continue;
    // Implicit feedback, as in MetaBrainz's recommender: what was played more counts more,
    // and a song mostly skipped counts for little.
    final weight = (1 + log(1 + seed.plays) - 0.5 * seed.skips).clamp(0.2, 4.0);
    for (var i = 0; i < list.length; i++) {
      // Earlier neighbours are closer, so they count more.
      votes[list[i]] = (votes[list[i]] ?? 0) + weight * (1 - i / (list.length + 1));
    }
  }
  final ranked = votes.entries.where((e) => !seedIds.contains(e.key) && !exclude.contains(e.key) && byId[e.key] != null).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final out = <Song>[];
  final perArtistCount = <String, int>{};
  for (final e in ranked) {
    final song = byId[e.key]!;
    final artist = firstArtist(song.artist).toLowerCase();
    if ((perArtistCount[artist] ?? 0) >= perArtist) continue;
    perArtistCount[artist] = (perArtistCount[artist] ?? 0) + 1;
    out.add(song);
    if (out.length == limit) break;
  }
  return out;
}
