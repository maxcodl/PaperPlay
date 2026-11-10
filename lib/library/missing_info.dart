import 'db.dart';

/// Something a song still lacks. [todo] ones are work the app hasn't done yet; the rest
/// were looked for and nothing was found, so they only change if a source starts to help.
enum Missing {
  waiting('Waiting for song info', todo: true),
  scanPending('Lyrics and genre not looked up yet', todo: true),
  noCover('No cover yet', todo: true),
  noMatch('No match found'),
  smallCover('Small cover only'),
  noAlbum('No album'),
  noYear('No year'),
  noGenre('No genre'),
  unknownArtist('Unknown artist');

  const Missing(this.label, {this.todo = false});
  final String label;
  final bool todo;
}

/// What [s] still lacks. With [lookupsOn] off the lyrics and genre scan never runs, so
/// it isn't counted as work that's left.
Set<Missing> missingOf(Song s, {required bool lookupsOn}) {
  final looked = s.enrichState != EnrichState.pending;
  final scanned = !lookupsOn || s.moodScannedAt > 0;
  return {
    if (!looked) Missing.waiting,
    if (lookupsOn && !scanned) Missing.scanPending,
    if (s.coverPath == null) Missing.noCover else if (!s.coverHiRes && s.coverAt == 0) Missing.smallCover,
    if (s.enrichState == EnrichState.noMatch) Missing.noMatch,
    if (looked && s.album.isEmpty) Missing.noAlbum,
    if (looked && s.year == null) Missing.noYear,
    if (looked && scanned && s.genre == null) Missing.noGenre,
    if (s.artist == 'Unknown artist') Missing.unknownArtist,
  };
}
