import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;

import '../library/db.dart';

/// The bytes at [uri], or null if they aren't there. A busy server (5xx or 429) is
/// asked again after each of [delays], since Cover Art Archive often answers 500 for a
/// moment. [onFailure] hears the status of the answer that ended it.
Future<Uint8List?> fetchWithRetry(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  List<Duration> delays = const [Duration(seconds: 2), Duration(seconds: 6)],
  void Function(int status)? onFailure,
}) async {
  for (var attempt = 0;; attempt++) {
    final res = await client.get(uri, headers: headers);
    if (res.statusCode == 200) return res.bodyBytes;
    final busy = res.statusCode >= 500 || res.statusCode == 429;
    if (!busy || attempt >= delays.length) {
      onFailure?.call(res.statusCode);
      return null;
    }
    await Future<void>.delayed(delays[attempt]);
  }
}

/// The album a MusicBrainz release belongs to. Cover Art Archive keeps the art for an
/// album apart from its releases, and often has it for one release when another has none.
String? releaseGroupOf(Map<String, dynamic> release) => (release['release-group'] as Map?)?['id'] as String?;

/// Other iTunes countries worth searching when the default one has no match, since each
/// catalogue holds songs the others don't. India covers Hindi, Tamil, Telugu and
/// Malayalam music, and Japan has Japanese songs the others lack.
List<String> extraStorefronts(String title, String artist) {
  final japanese = RegExp(r'[぀-ヿ]').hasMatch('$title $artist');
  return [if (japanese) 'JP', 'IN'];
}

/// What a song's own file says about it.
class EmbeddedTags {
  const EmbeddedTags({this.title, this.artist, this.album, this.year, this.genre});
  final String? title, artist, album, genre;
  final int? year;
}

/// What a file's own tags add to what's known. Only gaps are filled: an online match
/// keeps what it found, and a person's edits are never touched. Null when nothing's new.
SongsCompanion? fillFromTags(Song s, EmbeddedTags t) {
  if (s.userEdited) return null;
  final album = (t.album ?? '').trim(), genre = (t.genre ?? '').trim(), artist = (t.artist ?? '').trim();
  final year = t.year != null && t.year! >= 1900 && t.year! <= 2100 ? t.year : null;
  var fill = const SongsCompanion();
  if (s.album.isEmpty && album.isNotEmpty) fill = fill.copyWith(album: Value(album));
  if (s.year == null && year != null) fill = fill.copyWith(year: Value(year));
  if (s.genre == null && genre.isNotEmpty) fill = fill.copyWith(genre: Value(genre));
  if (s.artist == 'Unknown artist' && artist.isNotEmpty) fill = fill.copyWith(artist: Value(artist));
  if (fill.toColumns(false).isEmpty) return null;
  return s.metadataSource == null ? fill.copyWith(metadataSource: const Value('File tags')) : fill;
}
