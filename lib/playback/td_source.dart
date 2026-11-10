// just_audio marks its stream source API experimental; it is the only way to
// feed TDLib's partial file to the player. Pinned by pubspec.lock.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:just_audio/just_audio.dart';

import '../library/db.dart';
import '../telegram/td_client.dart';
import 'cache.dart';

/// Streams a song out of TDLib's partial download. Each range request moves
/// the download to the requested offset, so seeking works on files that
/// aren't downloaded yet.
class TdAudioSource extends StreamAudioSource {
  TdAudioSource(this.song, this._td, this._cache, {super.tag});

  final Song song;
  final TdClient _td;
  final CacheManager _cache;

  /// The bot that owns the file being streamed, whose file ids the requests use.
  TdClient? _bot;
  TdClient get _client => _bot ?? _td;

  static const _stallTimeout = Duration(seconds: 20);
  static const _chunk = 64 * 1024;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final (file, bot) = await _cache.fileAndBot(song);
    _bot = bot;
    final size = (file['size'] as int) != 0 ? file['size'] as int : file['expected_size'] as int;
    final from = start ?? 0;
    final to = end ?? size;
    return StreamAudioResponse(
      sourceLength: size,
      contentLength: to - from,
      offset: from,
      stream: _bytes(file['id'] as int, from, to),
      contentType: song.mime,
    );
  }

  Future<Json> _requestDownload(int id, int offset) => _client.call({
        '@type': 'downloadFile',
        'file_id': id,
        'priority': 32,
        'offset': offset,
        'limit': 0,
        'synchronous': false,
      });

  Stream<List<int>> _bytes(int id, int start, int end) async* {
    var pos = start;
    var lastProgress = DateTime.now();
    RandomAccessFile? raf;
    var file = await _requestDownload(id, pos);
    try {
      while (pos < end) {
        final prefix = await _client.call({
          '@type': 'getFileDownloadedPrefixSize',
          'file_id': id,
          'offset': pos,
        });
        final available = prefix['size'] as int;
        if (available > 0) {
          raf ??= await File((file['local'] as Json)['path'] as String).open();
          await raf.setPosition(pos);
          final bytes = await raf.read(min(min(available, _chunk), end - pos));
          pos += bytes.length;
          lastProgress = DateTime.now();
          yield bytes;
          continue;
        }
        if (DateTime.now().difference(lastProgress) > _stallTimeout) {
          throw TdError(0, 'Download stalled. Check your connection.');
        }
        final update = await _client
            .updatesOf('updateFile')
            .map((u) => u['file'] as Json)
            .where((f) => f['id'] == id)
            .first
            .timeout(const Duration(milliseconds: 500), onTimeout: () => file);
        file = update;
        // Another request may have moved or stopped this download.
        final local = file['local'] as Json;
        if (local['is_downloading_active'] != true) await _requestDownload(id, pos);
      }
    } finally {
      await raf?.close();
    }
  }
}
