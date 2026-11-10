import 'dart:io';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

/// `-6.54 dB` -> -6.54. Null if it isn't a gain.
double? parseGainDb(String? s) {
  if (s == null) return null;
  final m = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(s);
  return m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', '.'));
}

/// Volume factor for a track whose ReplayGain is [gainDb] (relative to -18 LUFS) with
/// [preampDb] added. Only turns the song down: never above 1, so nothing clips.
double normalizationFactor(double? gainDb, double preampDb) {
  if (gainDb == null) return 1;
  final f = pow(10, (gainDb + preampDb) / 20).toDouble();
  return f > 1 ? 1 : f;
}

/// ReplayGain track gain in a song's tags (ID3 TXXX, FLAC/Ogg comments). Null when
/// there is none, or the file isn't readable yet.
double? readTrackGainDb(File f) {
  try {
    final dynamic tag = readAllMetadata(f, getImage: false);
    try {
      final custom = tag.customMetadata as Map<String, String>;
      for (final e in custom.entries) {
        if (e.key.toUpperCase() == 'REPLAYGAIN_TRACK_GAIN') return parseGainDb(e.value);
      }
    } catch (_) {}
    try {
      final v = (tag.replayGainTrackGain as List).cast<String>();
      if (v.isNotEmpty) return parseGainDb(v.first);
    } catch (_) {}
  } catch (_) {}
  return null;
}
