import 'dart:convert';

import 'package:http/http.dart' as http;

import '../metadata/enricher.dart';
import 'db.dart';

/// One song that wasn't found in the library, with where to find it elsewhere.
class ExportRow {
  const ExportRow({
    required this.title,
    required this.artist,
    required this.durationSec,
    this.spotifyUrl,
    this.appleUrl,
  });

  final String title, artist;
  final int durationSec;

  /// Null when the source has no Spotify id, or no match was found.
  final String? spotifyUrl, appleUrl;

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'durationSec': durationSec,
        'spotifyUrl': spotifyUrl,
        'appleUrl': appleUrl,
      };

  factory ExportRow.fromJson(Map<String, dynamic> j) => ExportRow(
        title: j['title'] as String,
        artist: j['artist'] as String,
        durationSec: j['durationSec'] as int? ?? 0,
        spotifyUrl: j['spotifyUrl'] as String?,
        appleUrl: j['appleUrl'] as String?,
      );
}

/// A temporary list of songs with their links, kept on this device until it is deleted.
class ExportList {
  const ExportList({required this.id, required this.name, required this.createdAt, required this.rows});
  final String id, name;
  final int createdAt;
  final List<ExportRow> rows;

  int get withApple => rows.where((r) => r.appleUrl != null).length;
  int get withSpotify => rows.where((r) => r.spotifyUrl != null).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        'rows': [for (final r in rows) r.toJson()],
      };

  factory ExportList.fromJson(Map<String, dynamic> j) => ExportList(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: j['createdAt'] as int,
        rows: [for (final r in j['rows'] as List) ExportRow.fromJson(r as Map<String, dynamic>)],
      );
}

const _listsKey = 'export_lists';

Future<List<ExportList>> loadExportLists(AppDb db) async {
  final raw = await db.pref(_listsKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    return [for (final j in jsonDecode(raw) as List) ExportList.fromJson(j as Map<String, dynamic>)];
  } on Object {
    return []; // Damaged: they are temporary anyway.
  }
}

Future<void> saveExportLists(AppDb db, List<ExportList> lists) =>
    db.setPref(_listsKey, jsonEncode([for (final l in lists) l.toJson()]));

Future<void> deleteExportList(AppDb db, String id) async =>
    saveExportLists(db, [for (final l in await loadExportLists(db)) if (l.id != id) l]);

/// A Spotify link from the source's track id (`spotify:track:ID`), if it is one.
String? spotifyLinkOf(String trackKey) {
  final parts = trackKey.split(':');
  if (parts.length == 3 && parts[0] == 'spotify' && parts[1] == 'track' && parts[2].isNotEmpty) {
    return 'https://open.spotify.com/track/${parts[2]}';
  }
  return null;
}

/// Looks a song up in Apple Music through Apple's free search and returns the link of the
/// best match: same title, the artist inside the result's, length within 5 seconds.
/// Null if nothing fits. Tries the US catalogue, then India's, as the app does elsewhere.
Future<String?> appleLinkFor(
  http.Client client, {
  required String title,
  required String artist,
  required int durationSec,
  Duration pause = const Duration(milliseconds: 3200),
}) async {
  final wantTitle = comparableText(searchTitle(cleanTitle(title, artist)));
  final wantArtist = artist == 'Unknown artist' ? '' : comparableText(firstArtist(artist));
  if (wantTitle.isEmpty) return null;
  final term = '${searchTitle(cleanTitle(title, artist))} ${firstArtist(artist)}'.trim();
  for (final country in const [null, 'IN']) {
    // Apple allows about 20 searches a minute.
    if (pause > Duration.zero) await Future<void>.delayed(pause);
    final res = await client.get(Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'media': 'music',
      'entity': 'song',
      'limit': '10',
      'country': ?country,
    }));
    if (res.statusCode != 200) continue;
    final results = ((jsonDecode(utf8.decode(res.bodyBytes)) as Map)['results'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (final r in results) {
      final length = ((r['trackTimeMillis'] as num?) ?? 0) ~/ 1000;
      if (durationSec > 0 && length > 0 && (length - durationSec).abs() > 5) continue;
      if (comparableText(searchTitle(r['trackName'] as String? ?? '')) != wantTitle) continue;
      if (wantArtist.isNotEmpty && !comparableText(r['artistName'] as String? ?? '').contains(wantArtist)) continue;
      final url = r['trackViewUrl'] as String?;
      if (url != null) return url;
    }
  }
  return null;
}

/// Builds a list for [tracks]: Spotify links straight from their ids, Apple Music ones by
/// search, one at a time. [onProgress] is told how many are done; [cancelled] stops early and
/// keeps what was found.
Future<ExportList> buildExportList(
  List<MissingTrack> tracks,
  String name, {
  http.Client? client,
  void Function(int done, int total)? onProgress,
  bool Function()? cancelled,
  Duration pause = const Duration(milliseconds: 3200),
}) async {
  final http_ = client ?? http.Client();
  final rows = <ExportRow>[];
  try {
    for (final t in tracks) {
      if (cancelled?.call() == true) break;
      String? apple;
      try {
        apple = await appleLinkFor(http_, title: t.title, artist: t.artist, durationSec: t.durationSec, pause: pause);
      } on Object {
        apple = null; // Offline or refused: the row still has its Spotify link.
      }
      rows.add(ExportRow(
        title: t.title,
        artist: t.artist,
        durationSec: t.durationSec,
        spotifyUrl: spotifyLinkOf(t.trackKey),
        appleUrl: apple,
      ));
      onProgress?.call(rows.length, tracks.length);
    }
  } finally {
    if (client == null) http_.close();
  }
  final now = DateTime.now();
  return ExportList(id: '${now.microsecondsSinceEpoch}', name: name, createdAt: now.millisecondsSinceEpoch, rows: rows);
}

String _csv(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';

/// The list as a spreadsheet file: title, artist, length, Spotify link, Apple Music link.
String exportCsv(ExportList list) => [
      'title,artist,seconds,spotify,apple_music',
      for (final r in list.rows) [_csv(r.title), _csv(r.artist), r.durationSec, _csv(r.spotifyUrl), _csv(r.appleUrl)].join(','),
    ].join('\n');

/// Every link, one per line, to paste into a playlist importer or a message.
String exportLinks(ExportList list, {bool spotify = true, bool apple = true}) => [
      for (final r in list.rows) ...[
        if (spotify && r.spotifyUrl != null) r.spotifyUrl!,
        if (apple && r.appleUrl != null) r.appleUrl!,
      ],
    ].join('\n');
