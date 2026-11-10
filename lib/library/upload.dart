import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../telegram/bot_pool.dart';
import '../telegram/td_client.dart';
import '../telegram/td_compat.dart';
import 'album_art.dart';
import 'db.dart';
import 'scanner.dart';
import 'taste.dart';
import '../pace.dart';

enum UploadStatus { queued, uploading, done, failed, skipped }

class UploadJob {
  UploadJob(this.path, this.chatId, this.chatTitle, {this.temporary = false, this.topicId, this.topicName});
  final String path;
  final int chatId;
  final String chatTitle;

  /// Which forum topic to post in. Null posts to the chat itself.
  final int? topicId;
  final String? topicName;

  /// A copy made by the system's file picker, deleted once it's been sent.
  final bool temporary;
  var status = UploadStatus.queued;
  var progress = 0.0;
  var retries = 0;
  String? error;

  /// Name and size, to recognise the same file again.
  String? key;
}

/// What `sendMessage` needs to post in a topic. TDLib 1.8.52 takes
/// `message_thread_id` here, not `topic_id`, and ignores a field it doesn't know, which
/// would silently post to General. Posting without one is what reaches General itself.
Map<String, Object> topicField(int? topicId) => topicRequest(topicId, generalTopicId);

/// Whether [path] looks like audio the app accepts.
bool isAudioFile(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext.length > 1 && audioExtensions.contains(ext.substring(1));
}

const _songsPerLongRest = 20;

/// How long to wait before the next file. Posting steadily, with uneven gaps and a
/// longer rest now and then, looks less like a script and reduces the risk of
/// Telegram limiting the bot. It can't rule that out.
Duration uploadPause(int uploadedSoFar, Random random, {bool slower = false, Work work = Work.filing}) {
  final base = gap(work) * (slower ? 3 : 1);
  if (uploadedSoFar > 0 && uploadedSoFar % _songsPerLongRest == 0) {
    return base * (4 + random.nextDouble() * 4);
  }
  return base * (0.7 + random.nextDouble() * 0.6);
}

final _retryAfter = RegExp(r'retry after (\d+)|FLOOD_WAIT_(\d+)', caseSensitive: false);

/// How long Telegram asked to wait, if [error] is a rate limit.
Duration? retryAfterOf(Object error) {
  final m = _retryAfter.firstMatch('$error');
  if (m == null) return null;
  return Duration(seconds: int.parse(m.group(1) ?? m.group(2)!));
}

bool _startsWith(List<int> b, List<int> sig, [int at = 0]) {
  if (b.length < at + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[at + i] != sig[i]) return false;
  }
  return true;
}

List<int> _ascii(String s) => s.codeUnits;

/// Whether the file's own first bytes say it is audio of the kind its name claims. The
/// name alone isn't enough: a sticker or a video can be named anything. `.webm` is never
/// taken, since it is nearly always video.
bool looksLikeAudio(String path) {
  if (!isAudioFile(path)) return false;
  final ext = p.extension(path).toLowerCase().substring(1);
  if (ext == 'webm') return false;
  try {
    final f = File(path).openSync();
    try {
      final b = f.readSync(4096);
      if (b.length < 16) return false;
      bool riff(String kind) => _startsWith(b, _ascii('RIFF')) && _startsWith(b, _ascii(kind), 8);
      bool form(String kind) => _startsWith(b, _ascii('FORM')) && _startsWith(b, _ascii(kind), 8);
      bool mpegFrame() {
        for (var i = 0; i + 1 < b.length && i < 4000; i++) {
          if (b[i] == 0xFF && (b[i + 1] & 0xE0) == 0xE0) return true;
        }
        return false;
      }

      bool mp4Audio() {
        if (!_startsWith(b, _ascii('ftyp'), 4)) return false;
        final brand = String.fromCharCodes(b.sublist(8, 12));
        // Audio brands only; a plain mp4 or 3gp is a video.
        return brand == 'M4A ' || brand == 'M4B ' || brand == 'M4P ' || brand == 'mp42' && ext != 'mp4' && ext != '3gp';
      }

      return switch (ext) {
        'mp3' || 'mp2' => _startsWith(b, _ascii('ID3')) || mpegFrame(),
        'flac' => _startsWith(b, _ascii('fLaC')) || _startsWith(b, _ascii('ID3')),
        'm4a' || 'm4b' || 'alac' || 'mp4' || '3gp' => mp4Audio(),
        'aac' => _startsWith(b, _ascii('ID3')) || (b[0] == 0xFF && (b[1] & 0xF0) == 0xF0),
        'ogg' || 'oga' || 'opus' => _startsWith(b, _ascii('OggS')),
        'wav' => riff('WAVE'),
        'aiff' || 'aif' || 'aifc' => form('AIFF') || form('AIFC'),
        'wma' => _startsWith(b, const [0x30, 0x26, 0xB2, 0x75]),
        'ape' => _startsWith(b, _ascii('MAC ')),
        'wv' => _startsWith(b, _ascii('wvpk')),
        'tta' => _startsWith(b, _ascii('TTA1')),
        'tak' => _startsWith(b, _ascii('tBaK')),
        'dsf' => _startsWith(b, _ascii('DSD ')),
        'dff' => _startsWith(b, _ascii('FRM8')),
        'mpc' => _startsWith(b, _ascii('MP+')) || _startsWith(b, _ascii('MPCK')),
        'amr' => _startsWith(b, _ascii('#!AMR')),
        'ac3' => b[0] == 0x0B && b[1] == 0x77,
        'dts' => _startsWith(b, const [0x7F, 0xFE, 0x80, 0x01]),
        'caf' => _startsWith(b, _ascii('caff')),
        'mka' => _startsWith(b, const [0x1A, 0x45, 0xDF, 0xA3]),
        _ => false,
      };
    } finally {
      f.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}

/// [paths] split into the files that really are audio and how many were left out. Reads
/// each file's start on another isolate, so a big folder doesn't freeze the window.
Future<({List<String> audio, int rejected})> checkAudio(Iterable<String> paths) async {
  final all = paths.toList();
  final audio = await Isolate.run(() => all.where(looksLikeAudio).toList());
  return (audio: audio, rejected: all.length - audio.length);
}

/// Every audio file in [folder] and its subfolders, in order. Anything unreadable
/// is left out rather than ending the search.
Future<List<String>> audioFilesIn(Directory folder) async {
  final found = <String>[];
  await for (final e in folder.list(recursive: true, followLinks: false).handleError((_) {})) {
    if (e is File && isAudioFile(e.path)) found.add(e.path);
  }
  return found..sort();
}

class _Slot {
  _Slot(this.client);

  /// The bot sending this file. Message and file ids are only unique per bot.
  final TdClient client;
  int? messageId;
  int? fileId;
  final done = Completer<void>();
}

/// A few files at once (see [Uploader.parallel]), each worker pausing between its files. Only ever posts new messages; the
/// song row appears through the scanner when Telegram confirms the send.
class Uploader {
  Uploader(this._td, this._db, {BotPool? pool}) : _pool = pool {
    void listen(String type, void Function(TdClient, Json) handle) {
      _td.updatesOf(type).listen((u) => handle(_td, u));
      pool?.updatesOf(type).listen((e) => handle(e.$1, e.$2));
    }

    listen('updateFile', (c, u) => _onFile(c, u['file'] as Json));
    listen('updateMessageSendSucceeded', (c, u) {
      _finish(c, u['old_message_id'] as int);
      // Another bot's post may never reach the main bot, so the library hears of it here.
      if (c != _td) onSentByExtraBot?.call(u);
    });
    listen(
      'updateMessageSendFailed',
      (c, u) => _finish(c, u['old_message_id'] as int, (u['error'] as Json)['message'] as String),
    );
  }

  final BotPool? _pool;

  /// Told of a post an extra bot sent, so the song appears whether or not the main bot sees it.
  void Function(Json update)? onSentByExtraBot;

  /// Whether a bot may post in a chat; uploads go nowhere it can only read.
  Future<bool> Function(TdClient bot, int chat) canWriteWith = (_, _) async => true;

  List<TdClient> get _bots => _pool?.ready.isNotEmpty == true ? _pool!.ready : [_td];

  /// Bots Telegram has told to wait, and until when. One bot's limit doesn't stop the others.
  final _floodUntil = <TdClient, DateTime>{};

  final TdClient _td;
  final AppDb _db;
  final _random = Random();
  static const _maxRateLimitRetries = 5;

  /// Rebuilt on every change, for the uploads screen.
  final jobs = ValueNotifier<List<UploadJob>>([]);

  /// When the next file starts, while waiting between files.
  final nextAt = ValueNotifier<DateTime?>(null);
  final paused = ValueNotifier(false);

  /// Longer gaps between files, for very large uploads.
  final slower = ValueNotifier(false);

  /// Leave out files already in the library.
  final skipKnown = ValueNotifier(true);

  Future<void> loadSettings() async {
    slower.value = await _db.pref('upload_slower') == 'true';
    skipKnown.value = await _db.pref('upload_skip_known') != 'false';
    parallel.value = (int.tryParse(await _db.pref('upload_parallel') ?? '') ?? 6).clamp(1, maxParallel);
  }

  Future<void> setSlower(bool on) {
    slower.value = on;
    return _db.setPref('upload_slower', '$on');
  }

  Future<void> setSkipKnown(bool on) {
    skipKnown.value = on;
    return _db.setPref('upload_skip_known', '$on');
  }

  /// How many files are sent at once.
  /// Telegram allows a bot about 20 messages a minute in one group, so 20 at once is the
  /// ceiling; the speed setting and flood waits keep it under that.
  final parallel = ValueNotifier(6);
  static const maxParallel = 20;

  Future<void> setParallel(int n) {
    parallel.value = n.clamp(1, maxParallel);
    _pump();
    return _db.setPref('upload_parallel', '${parallel.value}');
  }

  /// Files being sent now, with what TDLib needs to match its updates to each.
  final _slots = <UploadJob, _Slot>{};
  var _uploaded = 0;
  var _workers = 0;

  void _changed() => jobs.value = [...jobs.value];

  void enqueue(
    Iterable<String> paths,
    int chatId,
    String chatTitle, {
    bool temporary = false,
    int? topicId,
    String? topicName,
  }) {
    jobs.value = [
      ...jobs.value,
      for (final path in paths)
        UploadJob(path, chatId, chatTitle, temporary: temporary, topicId: topicId, topicName: topicName),
    ];
    _pump();
    unawaited(_precheck());
  }

  var _prechecking = false, _precheckAgain = false;

  /// Looks at every waiting file at once, so known ones are marked skipped right away
  /// instead of only when a sending slot reaches them, however long the queue is.
  Future<void> _precheck() async {
    if (_prechecking) {
      _precheckAgain = true;
      return;
    }
    _prechecking = true;
    try {
      do {
        _precheckAgain = false;
        if (!skipKnown.value) return;
        final sent = await _sentFiles(), known = await _known();
        final seen = <String>{};
        var changed = false;
        for (final job in jobs.value.toList()) {
          if (job.status == UploadStatus.skipped || job.status == UploadStatus.failed) continue;
          final String name;
          final int size;
          try {
            name = p.basename(job.path).toLowerCase();
            size = await File(job.path).length();
          } on FileSystemException {
            continue;
          }
          final key = job.key = '$name|$size';
          // The same file twice in the list counts too: the first stays, later ones go.
          final repeat = !seen.add(key);
          if (job.status == UploadStatus.queued && (repeat || sent.containsKey(key) || known.contains((name, size)))) {
            job.status = UploadStatus.skipped;
            _removeCopy(job);
            changed = true;
          }
        }
        if (changed) _changed();
      } while (_precheckAgain);
    } finally {
      _prechecking = false;
    }
  }

  void retry(UploadJob job) {
    job
      ..status = UploadStatus.queued
      ..error = null
      ..progress = 0
      ..retries = 0;
    _changed();
    _pump();
  }

  void clearFinished() {
    jobs.value = jobs.value
        .where((j) => j.status != UploadStatus.done && j.status != UploadStatus.skipped)
        .toList();
  }

  /// Drops one file that is waiting or failed. A file being sent carries on.
  void remove(UploadJob job) {
    if (job.status == UploadStatus.uploading) return;
    _removeCopy(job);
    jobs.value = jobs.value.where((j) => j != job).toList();
  }

  /// Removes everything still waiting. The file being sent carries on.
  void cancelWaiting() {
    for (final j in jobs.value.where((j) => j.status == UploadStatus.queued)) {
      _removeCopy(j);
    }
    jobs.value = jobs.value.where((j) => j.status != UploadStatus.queued).toList();
  }

  void setPaused(bool value) {
    paused.value = value;
    if (!value) _pump();
  }

  Future<void> _wait(Duration d) async {
    nextAt.value = DateTime.now().add(d);
    await Future<void>.delayed(d);
    nextAt.value = null;
  }

  /// What's already in the library, to spot files that were uploaded before.
  Future<Set<(String, int)>> _known() async => {
        for (final s in await _db.select(_db.songs).get()) (s.fileName.toLowerCase(), s.size),
      };

  /// Starts workers up to [parallel]; each takes the next waiting file until none is left.
  void _pump() {
    while (_workers < parallel.value && !paused.value && jobs.value.any((j) => j.status == UploadStatus.queued)) {
      _workers++;
      _worker().whenComplete(() => _workers--);
    }
  }

  Future<void> _worker() async {
    {
      while (!paused.value && _workers <= parallel.value) {
        // Only when every bot has been told to wait does a worker wait too.
        final now = DateTime.now();
        final until = [for (final b in _bots) _floodUntil[b]];
        if (until.every((t) => t != null && t.isAfter(now))) {
          final soonest = until.whereType<DateTime>().reduce((a, b) => a.isBefore(b) ? a : b);
          await Future<void>.delayed(soonest.difference(now));
          continue;
        }
        final job = jobs.value.where((j) => j.status == UploadStatus.queued).firstOrNull;
        if (job == null) return;
        job.status = UploadStatus.uploading; // Claimed before any await, so no two workers share a file.
        if (await _isDuplicate(job)) {
          job.status = UploadStatus.skipped;
          _removeCopy(job);
          _changed();
          continue;
        }
        _changed();
        Duration? rateLimit;
        TdClient? usedBot;
        try {
          usedBot = await _pickBot(job);
          await _send(job, usedBot);
          job.status = UploadStatus.done;
          _uploaded++;
          unawaited(_remember(job));
          _removeCopy(job);
        } catch (e) {
          rateLimit = retryAfterOf(e);
          if (rateLimit != null && job.retries < _maxRateLimitRetries) {
            job
              ..retries += 1
              ..status = UploadStatus.queued
              ..progress = 0;
          } else {
            job
              ..status = UploadStatus.failed
              ..error = '$e';
            rateLimit = null;
          }
        }
        _slots.remove(job);
        _changed();
        if (rateLimit != null) {
          // Telegram said how long, for that bot. A margin on top avoids hitting it again at once.
          final wait = rateLimit + Duration(seconds: 5 + _random.nextInt(11));
          _floodUntil[usedBot ?? _td] = DateTime.now().add(wait);
          if (_bots.length < 2) await _wait(wait);
        } else if (jobs.value.any((j) => j.status == UploadStatus.queued)) {
          await _wait(uploadPause(_uploaded, _random, slower: slower.value, work: Work.uploads));
        }
      }
    }
  }

  static const _sentKey = 'uploaded_files';

  /// Files this app has sent, by name and size, kept across restarts. The library only
  /// learns of a song once Telegram confirms it and the scan reads it, so this closes the gap.
  Map<String, int>? _sent;

  Future<Map<String, int>> _sentFiles() async =>
      _sent ??= (jsonDecode(await _db.pref(_sentKey) ?? '{}') as Map).cast<String, int>();

  Future<bool> _isDuplicate(UploadJob job) async {
    try {
      final name = p.basename(job.path).toLowerCase(), size = await File(job.path).length();
      job.key = '$name|$size';
      if (!skipKnown.value) return false;
      return (await _sentFiles()).containsKey(job.key) || (await _known()).contains((name, size));
    } on FileSystemException {
      return false; // Sending it reports the problem properly.
    }
  }

  Future<void> _remember(UploadJob job) async {
    final key = job.key;
    if (key == null) return;
    (await _sentFiles())[key] = DateTime.now().millisecondsSinceEpoch;
    await _db.setPref(_sentKey, jsonEncode(_sent));
  }

  /// Forgets what was sent, so those files can be uploaded again.
  Future<void> forgetSent() async {
    _sent = {};
    await _db.setPref(_sentKey, '{}');
  }

  void _removeCopy(UploadJob job) {
    if (!job.temporary) return;
    try {
      File(job.path).deleteSync();
    } on FileSystemException {
      // Already gone; the system clears its picker cache eventually anyway.
    }
  }

  /// The bot with the fewest files in flight that may post in the job's chat and isn't
  /// being made to wait.
  Future<TdClient> _pickBot(UploadJob job) async {
    final now = DateTime.now();
    final usable = <TdClient>[];
    final waiting = <DateTime>[];
    for (final b in _bots) {
      final wait = _floodUntil[b];
      if (wait != null && wait.isAfter(now)) {
        waiting.add(wait);
        continue;
      }
      if (await canWriteWith(b, job.chatId)) usable.add(b);
    }
    if (usable.isEmpty && waiting.isNotEmpty) {
      await Future<void>.delayed(waiting.reduce((a, b) => a.isBefore(b) ? a : b).difference(now));
      return _pickBot(job);
    }
    if (usable.isEmpty) {
      throw StateError(_bots.length > 1
          ? "None of your bots is an admin there, so none can post."
          : "Your bot isn't an admin there, so it can't post.");
    }
    int load(TdClient b) => _slots.values.where((s) => s.client == b).length;
    usable.sort((a, b) => load(a).compareTo(load(b)));
    final bot = usable.first;
    _slots[job] = _Slot(bot); // Counted at once, so the next file goes to another bot.
    return bot;
  }

  Future<void> _send(UploadJob job, TdClient bot) async {
    final file = File(job.path);
    AudioMetadata? tags;
    try {
      tags = readMetadata(file, getImage: true);
    } catch (_) {
      tags = null; // Untagged files still upload; the filename is used instead.
    }
    final parsed = parseFileName(p.basename(job.path));
    final cover = await _coverFile(tags);
    try {
      final slot = _slots[job] ??= _Slot(bot);
      final message = await bot.call({
        '@type': 'sendMessage',
        'chat_id': job.chatId,
        ...topicField(job.topicId),
        'input_message_content': audioContent(
          {'@type': 'inputFileLocal', 'path': job.path},
          duration: tags?.duration?.inSeconds ?? 0,
          title: tags?.title ?? parsed.title,
          performer: tags?.artist ?? parsed.artist,
          cover: cover == null
              ? null
              : {
                  '@type': 'inputThumbnail',
                  'thumbnail': {'@type': 'inputFileLocal', 'path': cover.file.path},
                  'width': cover.thumb.width,
                  'height': cover.thumb.height,
                },
        ),
      });
      slot.messageId = message['id'] as int;
      final payload = audioPayload(message);
      slot.fileId = payload == null ? null : payloadFile(payload)['id'] as int;
      await slot.done.future;
    } finally {
      // Needed until the upload ends, since TDLib reads it as it goes.
      if (cover != null) unawaited(cover.file.delete().then<void>((_) {}, onError: (_) {}));
    }
  }

  /// The cover inside the file, shrunk to fit and saved for TDLib. Null when the file has
  /// none or it can't be used: the song is posted without a cover, as before.
  Future<({File file, CoverThumb thumb})?> _coverFile(AudioMetadata? tags) async {
    final picture = tags?.pictures.firstOrNull;
    if (picture == null) return null;
    try {
      final thumb = await shrinkCoverInBackground(picture.bytes);
      if (thumb == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'cover_${DateTime.now().microsecondsSinceEpoch}.jpg'));
      await file.writeAsBytes(thumb.bytes);
      return (file: file, thumb: thumb);
    } catch (_) {
      return null;
    }
  }

  void _onFile(TdClient bot, Json file) {
    final job = _slots.entries.where((e) => e.value.client == bot && e.value.fileId == file['id']).firstOrNull?.key;
    if (job == null) return;
    final size = file['size'] as int;
    if (size > 0) {
      job.progress = ((file['remote'] as Json)['uploaded_size'] as int) / size;
      _changed();
    }
  }

  void _finish(TdClient bot, int oldMessageId, [String? error]) {
    final slot = _slots.values.where((s) => s.client == bot && s.messageId == oldMessageId).firstOrNull;
    if (slot == null) return;
    error == null ? slot.done.complete() : slot.done.completeError(error);
  }

  /// Whether any of the bots may post audio to [chatId].
  Future<bool> canPost(int chatId) async {
    for (final bot in _bots) {
      try {
        if (await _canPostWith(bot, chatId)) return true;
      } on TdError {
        if (bot == _td) rethrow;
      }
    }
    return false;
  }

  Future<bool> _canPostWith(TdClient td, int chatId) async {
    final chat = await td.call({'@type': 'getChat', 'chat_id': chatId});
    final type = chat['type'] as Json;
    final allowed = (chat['permissions'] as Json?)?['can_send_audios'] == true;
    switch (type['@type']) {
      case 'chatTypePrivate':
      case 'chatTypeSecret':
        return true;
      case 'chatTypeSupergroup':
        final group = await td.call({
          '@type': 'getSupergroup',
          'supergroup_id': type['supergroup_id'],
        });
        final status = group['status'] as Json;
        if (status['@type'] == 'chatMemberStatusCreator') return true;
        final isAdmin = status['@type'] == 'chatMemberStatusAdministrator';
        if (type['is_channel'] == true) {
          return isAdmin && (status['rights'] as Json)['can_post_messages'] == true;
        }
        return isAdmin || allowed;
      default:
        return allowed;
    }
  }
}
