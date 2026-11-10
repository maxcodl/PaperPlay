import 'dart:typed_data';

import 'db.dart';

const _extensionFormats = {
  'mp3': 'MP3',
  'mpga': 'MP3',
  'mp2': 'MP2',
  'flac': 'FLAC',
  'm4a': 'AAC',
  'm4b': 'AAC',
  'mp4': 'AAC',
  'aac': 'AAC',
  'alac': 'ALAC',
  'ogg': 'OGG',
  'oga': 'OGG',
  'opus': 'OPUS',
  'wav': 'WAV',
  'aif': 'AIFF',
  'aiff': 'AIFF',
  'aifc': 'AIFF',
  'ape': 'APE',
  'wv': 'WV',
  'tak': 'TAK',
  'tta': 'TTA',
  'dsf': 'DSD',
  'dff': 'DSD',
  'wma': 'WMA',
  'ac3': 'AC3',
  'eac3': 'EAC3',
  'ec3': 'EAC3',
  'mka': 'MKA',
};

const _mimeFormats = {
  'audio/mpeg': 'MP3',
  'audio/mp3': 'MP3',
  'audio/flac': 'FLAC',
  'audio/x-flac': 'FLAC',
  'audio/mp4': 'AAC',
  'audio/x-m4a': 'AAC',
  'audio/aac': 'AAC',
  'audio/ogg': 'OGG',
  'audio/opus': 'OPUS',
  'audio/wav': 'WAV',
  'audio/x-wav': 'WAV',
  'audio/aiff': 'AIFF',
  'audio/x-aiff': 'AIFF',
  'audio/x-ms-wma': 'WMA',
  'audio/ac3': 'AC3',
};

/// Short format name, from the file extension or else the MIME type. An unknown
/// extension is shown as it is, since it still says more than "Audio".
String audioFormat(String mime, String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot > 0 && fileName.length - dot <= 6 ? fileName.substring(dot + 1) : '';
  return _extensionFormats[extension.toLowerCase()] ??
      _mimeFormats[mime.toLowerCase()] ??
      (extension.isEmpty ? 'Audio' : extension.toUpperCase());
}

/// Whether a format keeps all the original audio data.
bool isLossless(String format) =>
    const {'FLAC', 'WAV', 'ALAC', 'APE', 'AIFF', 'WV', 'TAK', 'TTA', 'DSD'}.contains(format);

/// Average bitrate worked out from size and length; null when length is unknown.
/// Embedded cover art counts towards the size, so it can read slightly high.
int? averageKbps(int sizeBytes, int durationSec) =>
    durationSec > 0 ? (sizeBytes * 8 / durationSec / 1000).round() : null;

String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  return bytes >= gb
      ? '${(bytes / gb).toStringAsFixed(1)} GB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}

enum QualityTier {
  hiRes('Hi-Res Lossless'),
  lossless('Lossless'),
  high('High quality'),
  standard('Standard');

  const QualityTier(this.label);
  final String label;
}

/// Lossy at this average bitrate or more counts as high quality.
const _highKbps = 256;

/// Hi-Res needs known values: a lossless file isn't called Hi-Res on a guess.
QualityTier qualityTier(String format, {int? kbps, int? sampleRate, int? bitDepth}) {
  if (isLossless(format)) {
    final hiRes = (bitDepth ?? 0) >= 24 && (sampleRate ?? 0) > 48000;
    return hiRes ? QualityTier.hiRes : QualityTier.lossless;
  }
  return (kbps ?? 0) >= _highKbps ? QualityTier.high : QualityTier.standard;
}

String songFormat(Song s) => s.codec ?? audioFormat(s.mime, s.fileName);

QualityTier songTier(Song s) => qualityTier(
      songFormat(s),
      kbps: averageKbps(s.size, s.durationSec),
      sampleRate: s.sampleRate,
      bitDepth: s.bitDepth,
    );

/// `44.1 kHz`, without a pointless `.0`.
String formatKhz(int sampleRate) {
  final khz = sampleRate / 1000;
  return '${khz == khz.roundToDouble() ? khz.round() : khz.toStringAsFixed(1)} kHz';
}

/// `FLAC · 24-bit/96 kHz` when known, otherwise `AAC · 256 kbps`.
/// Quality detail and size, beside the format label: "24-bit/96 kHz · 37 MB".
String songDetails(Song s) {
  final line = qualityLine(s);
  final detail = line.contains(' · ') ? line.substring(line.indexOf(' · ') + 3) : null;
  return [?detail, formatBytes(s.size)].join(' · ');
}

String qualityLine(Song s) {
  final format = songFormat(s);
  final kbps = averageKbps(s.size, s.durationSec);
  final depth = s.bitDepth, rate = s.sampleRate;
  if (isLossless(format) && depth != null && rate != null) {
    return '$format · $depth-bit/${formatKhz(rate)}';
  }
  return kbps == null ? format : '$format · $kbps kbps';
}

/// Better first: higher tier, then more detail, then bitrate, then size.
int compareQuality(Song a, Song b) {
  final tier = songTier(a).index.compareTo(songTier(b).index);
  if (tier != 0) return tier;
  final depth = (b.bitDepth ?? 0).compareTo(a.bitDepth ?? 0);
  if (depth != 0) return depth;
  final rate = (b.sampleRate ?? 0).compareTo(a.sampleRate ?? 0);
  if (rate != 0) return rate;
  return b.size.compareTo(a.size);
}

class AudioHeader {
  const AudioHeader({this.codec, this.sampleRate, this.bitDepth});
  final String? codec;
  final int? sampleRate, bitDepth;
}

bool _tagAt(Uint8List b, int at, String tag) {
  if (at < 0 || at + tag.length > b.length) return false;
  for (var i = 0; i < tag.length; i++) {
    if (b[at + i] != tag.codeUnitAt(i)) return false;
  }
  return true;
}

/// Reads sample rate and bit depth from the start of a FLAC, WAV or MP4 file. For
/// MP4, [bytes] should hold the `moov` box, which can be at the end. Null when it
/// isn't one of those, or the part needed isn't there.
AudioHeader? parseAudioHeader(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (_tagAt(bytes, 0, 'fLaC') && bytes.length >= 26) {
    // STREAMINFO, after the 4-byte marker, 4-byte block header and 10 bytes of sizes:
    // 20 bits of sample rate, 3 of channels, 5 of bits per sample minus one.
    final rate = (bytes[18] << 12) | (bytes[19] << 4) | (bytes[20] >> 4);
    final depth = (((bytes[20] & 1) << 4) | (bytes[21] >> 4)) + 1;
    return rate > 0 ? AudioHeader(sampleRate: rate, bitDepth: depth) : null;
  }
  if (_tagAt(bytes, 0, 'RIFF') && _tagAt(bytes, 8, 'WAVE')) {
    var at = 12;
    while (at + 8 <= bytes.length) {
      final size = data.getUint32(at + 4, Endian.little);
      if (_tagAt(bytes, at, 'fmt ') && at + 24 <= bytes.length) {
        return AudioHeader(
          sampleRate: data.getUint32(at + 12, Endian.little),
          bitDepth: data.getUint16(at + 22, Endian.little),
        );
      }
      at += 8 + size + size % 2;
    }
    return null;
  }
  for (var at = 4; at + 46 <= bytes.length; at++) {
    if (!_tagAt(bytes, at, 'stsd')) continue;
    // After the box's version, flags and entry count: entry size, then the codec.
    final codecAt = at + 16;
    if (_tagAt(bytes, codecAt, 'mp4a')) {
      // 16.16 fixed point, so this is the whole number part.
      final rate = data.getUint16(codecAt + 28);
      return rate > 0 ? AudioHeader(sampleRate: rate) : null;
    }
    if (_tagAt(bytes, codecAt, 'alac')) {
      // The entry's own fields can't hold rates over 65535, so its nested box is
      // read when it's there.
      if (_tagAt(bytes, codecAt + 36, 'alac') && codecAt + 68 <= bytes.length) {
        return AudioHeader(codec: 'ALAC', bitDepth: bytes[codecAt + 49], sampleRate: data.getUint32(codecAt + 64));
      }
      return AudioHeader(codec: 'ALAC', bitDepth: data.getUint16(codecAt + 22), sampleRate: data.getUint16(codecAt + 28));
    }
  }
  return null;
}
