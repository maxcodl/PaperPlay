import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../telegram/td_client.dart';
import 'db.dart';
import 'taste.dart';
import '../pace.dart';

/// TDLib message ids are the server id shifted left by 20 bits.
const messageIdStep = 1 << 20;

/// [count] consecutive message ids starting at [start].
List<int> idsFrom(int start, int count) =>
    [for (var i = 0; i < count; i++) start + i * messageIdStep];

/// Every audio format the app accepts, for uploads and for spotting songs posted
/// as plain files. Some may upload here but only play on a PC.
const audioExtensions = {
  'mp3', 'flac', 'm4a', 'm4b', 'mp4', 'aac', 'ogg', 'oga', 'opus', 'wav', 'wma', 'alac', 'ape', 'aiff', 'aif',
  'aifc', 'wv', 'mka', 'webm', 'dsf', 'dff', 'mpc', 'tta', 'tak', 'amr', 'ac3', 'dts', 'mp2', 'caf', '3gp',
};

/// Splits `01. Artist - Title.mp3` into artist and title; artist may be empty.
({String artist, String title}) parseFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  var name = dot > 0 ? fileName.substring(0, dot) : fileName;
  name = name.replaceAll('_', ' ').replaceFirst(RegExp(r'^\s*\d{1,3}\s*[.\-)]\s*'), '').trim();
  final sep = name.indexOf(' - ');
  if (sep < 0) return (artist: '', title: name);
  return (artist: name.substring(0, sep).trim(), title: name.substring(sep + 3).trim());
}

/// The audio or document payload of [message], if it holds a song.
Json? audioPayload(Json message) {
  final content = message['content'] as Json;
  switch (content['@type']) {
    case 'messageAudio':
      return content['audio'] as Json;
    case 'messageDocument':
      final doc = content['document'] as Json;
      final mime = doc['mime_type'] as String? ?? '';
      final ext = (doc['file_name'] as String? ?? '').split('.').last.toLowerCase();
      return mime.startsWith('audio/') || audioExtensions.contains(ext) ? doc : null;
  }
  return null;
}

/// The downloadable file inside an [audioPayload].
Json payloadFile(Json payload) => (payload['audio'] ?? payload['document']) as Json;

/// Album art thumbnail of an [audioPayload], if Telegram has one.
Json? payloadThumbnail(Json payload) =>
    (payload['album_cover_thumbnail'] ?? payload['thumbnail']) as Json?;

/// The forum topic a message is in, if its chat has topics.
int? topicIdOf(Json message) => (message['topic_id'] as Json?)?['forum_topic_id'] as int?;

SongsCompanion? songFromMessage(Json message) {
  final payload = audioPayload(message);
  if (payload == null) return null;
  final file = payloadFile(payload);
  final remote = file['remote'] as Json;
  final fileName = payload['file_name'] as String? ?? '';
  final parsed = parseFileName(fileName);
  String tag(String key) => (payload[key] as String? ?? '').trim();
  final title = tag('title').isNotEmpty ? tag('title') : parsed.title;
  final artist = tag('performer').isNotEmpty ? tag('performer') : parsed.artist;
  final size = file['size'] as int;
  return SongsCompanion.insert(
    chatId: message['chat_id'] as int,
    messageId: message['id'] as int,
    uniqueId: remote['unique_id'] as String,
    remoteId: remote['id'] as String,
    title: title.isEmpty ? 'Unknown title' : title,
    artist: artist.isEmpty ? 'Unknown artist' : artist,
    durationSec: Value(payload['duration'] as int? ?? 0),
    size: size != 0 ? size : file['expected_size'] as int,
    mime: payload['mime_type'] as String? ?? 'audio/mpeg',
    fileName: fileName,
    date: message['date'] as int,
    topicId: Value(topicIdOf(message)),
  );
}

/// How far a full bot read has got, 0 to 1. Null when no total is known: a
/// partial read, or once past the newest message the library knows about.
double? walkShare(int next, int knownEnd, {required bool full}) =>
    full && knownEnd > 0 && next <= knownEnd ? next / knownEnd : null;

class Scanner {
  Scanner(this._td, this._db) {
    _td.updatesOf('updateNewMessage').listen(_onMessage);
    _td.updatesOf('updateMessageSendSucceeded').listen(_onMessage);
    _td.updatesOf('updateDeleteMessages').listen(_onDelete);
    _td.updatesOf('updateForumTopicInfo').listen(_onTopicInfo);
    _db.watchChats().listen((chats) => _chats = {for (final c in chats) c.id});
  }

  final TdClient _td;
  final AppDb _db;

  /// IDs requested per step when the bot walks a chat. Bots can't list history.
  static const _walkBatch = 50;

  /// Pause between steps. Telegram rate-limited a faster pace (100 ids every
  /// 2 seconds), so this starts gentle and doubles after every rate limit.
  Duration _walkPause = const Duration(seconds: 3);
  static const _maxWalkPause = Duration(minutes: 1);

  /// Empty batches in a row, past the known end, that mean the walk is done.
  static const _walkEmptyLimit = 3;

  /// The same with no known end: deleted posts can leave long gaps, and
  /// stopping early would miss everything after one. 2,000 ids takes 40 seconds.
  static const _firstWalkEmptyLimit = 20;
  var _chats = <int>{};

  /// Human-readable progress; null when idle.
  final progress = ValueNotifier<String?>(null);

  /// Share of the current job done, 0 to 1; null when the total isn't known.
  final fraction = ValueNotifier<double?>(null);

  /// Run after a scan adds songs.
  VoidCallback? onSongsAdded;

  /// A post an extra bot sent, handled as if the main bot had seen it: bots don't always
  /// see each other's posts in a group.
  void ingest(Json update) => _onMessage(update);

  void _onMessage(Json u) {
    final message = u['message'] as Json;
    final chatId = message['chat_id'] as int;
    // A pending upload has a temporary id; it arrives again on send success.
    if (message['sending_state'] != null || !_chats.contains(chatId)) return;
    // Heard live, so the next start needn't read it again. Only once this session has read
    // the chat up to now: before that there could be posts nobody has read in between.
    if (_caughtUp.contains(chatId)) unawaited(_db.advanceScanned(chatId, message['id'] as int));
    unawaited(_saveTopicName(message));
    final song = songFromMessage(message);
    if (song == null) return;
    _db.upsertBotSong(song).then((isNew) {
      if (isNew) onSongsAdded?.call();
    });
  }

  /// Chats this session has finished reading, so live posts can move their mark forward.
  final _caughtUp = <int>{};

  void _onDelete(Json u) {
    if (u['is_permanent'] != true || u['from_cache'] == true) return;
    final chatId = u['chat_id'] as int;
    if (!_chats.contains(chatId)) return;
    for (final id in (u['message_ids'] as List).cast<int>()) {
      _db.postDeleted(chatId, id);
    }
  }

  void _onTopicInfo(Json u) {
    final info = u['info'] as Json?;
    final chatId = (info?['chat_id'] ?? u['chat_id']) as int?;
    final topic = (info?['forum_topic_id'] ?? info?['message_thread_id']) as int?;
    final name = info?['name'] as String?;
    if (chatId == null || topic == null || name == null || !_chats.contains(chatId)) return;
    _db.saveTopic(chatId, topic, name);
  }

  /// A topic's name is in the message that created it, and those that renamed it.
  Future<void> _saveTopicName(Json message) async {
    final content = message['content'] as Json;
    final type = content['@type'];
    if (type != 'messageForumTopicCreated' && type != 'messageForumTopicEdited') return;
    final name = content['name'] as String?;
    if (name == null || name.isEmpty) return;
    final chatId = message['chat_id'] as int;
    final id = type == 'messageForumTopicCreated' ? message['id'] as int : topicIdOf(message);
    if (id != null) await _db.saveTopic(chatId, id, name);
  }

  /// Names General, which has no creation message, so nothing else ever does. Other topics'
  /// current names can't be asked for: Telegram refuses `getForumTopic` to bots every time
  /// (BOT_METHOD_INVALID), so those come from the creation and rename messages only.
  Future<void> refreshTopicNames(int chatId) async {
    final general = _db.select(_db.songs)
      ..where((s) => s.chatId.equals(chatId) & s.topicId.equals(generalTopicId))
      ..limit(1);
    if (await general.getSingleOrNull() != null) await _db.saveTopic(chatId, generalTopicId, 'General');
  }

  /// True on a phone while a PC is connected: the PC reads the history, and its results
  /// (songs and how far each chat was read) reach the phone through the sync.
  bool Function() offloaded = () => false;

  /// Scans library chats for newer messages.
  Future<void> catchUp() async {
    if (offloaded()) return;
    for (final chat in await _db.select(_db.libraryChats).get()) {
      await scanChat(chat);
    }
  }

  /// Rescans from scratch and drops songs whose message no longer exists.
  /// Only needed for deletions that happened while the app was closed.
  Future<void> fullRescan() async {
    for (final chat in await _db.select(_db.libraryChats).get()) {
      await rescanChat(chat);
    }
  }

  Future<void> rescanChat(LibraryChat chat) async {
    final seen = await scanChat(chat, full: true);
    // A failed scan saw only part of the chat, so it proves nothing was deleted.
    if (seen == null) return;
    final extra = await _db.extraBotPosts();
    for (final s in await _db.songsInChat(chat.id)) {
      if (!seen.contains(s.messageId) && !extra.contains('${s.chatId}:${s.messageId}')) {
        await _db.postDeleted(s.chatId, s.messageId);
      }
    }
  }

  /// Bots can't list history, but can fetch messages by id, so this requests
  /// ids in order. It never stops before the newest message already known.
  /// Returns ids of all song messages seen, or null if the scan failed.
  /// [endHint] is a message id known to exist, for a first read.
  Future<Set<int>?> scanChat(LibraryChat chat, {bool full = false, int endHint = 0}) async {
    final rows = await _db.songsInChat(chat.id);
    final last = chat.lastScannedMessageId;
    final knownEnd = max(endHint, max(rows.isEmpty ? 0 : rows.last.messageId, last ?? 0));
    final emptyLimit = chat.walkDone ? _walkEmptyLimit : _firstWalkEmptyLimit;
    var next = full || last == null ? messageIdStep : last + messageIdStep;
    var newest = last ?? 0;
    var empties = 0;
    final seen = <int>{};
    var added = 0;
    try {
      while (true) {
        // Removed from the library while this was reading: nothing more to save.
        if (await (_db.select(_db.libraryChats)..where((c) => c.id.equals(chat.id))).getSingleOrNull() == null) {
          return seen;
        }
        final page = await _retrying(
          () => _td.call({
            '@type': 'getMessages',
            'chat_id': chat.id,
            'message_ids': idsFrom(next, _walkBatch),
          }),
          onRateLimit: () {
            final doubled = _walkPause * 2;
            _walkPause = doubled > _maxWalkPause ? _maxWalkPause : doubled;
          },
        );
        final messages = (page['messages'] as List).cast<Json?>().whereType<Json>().toList();
        // One write per step, so the song list grows in steps, not per song.
        await _db.transaction(() async {
          for (final m in messages) {
            newest = max(newest, m['id'] as int);
            await _saveTopicName(m);
            final song = songFromMessage(m);
            if (song == null) continue;
            seen.add(m['id'] as int);
            if (await _db.upsertBotSong(song)) added++;
          }
          // Saved each step, so a closed app continues here. Only real message
          // ids are saved: anything further could skip posts made later.
          if (!full) {
            await (_db.update(_db.libraryChats)..where((c) => c.id.equals(chat.id))).write(
              LibraryChatsCompanion(lastScannedMessageId: Value(newest)),
            );
          }
        });
        if (added > 0) onSongsAdded?.call();
        next += _walkBatch * messageIdStep;
        final share = walkShare(next, knownEnd, full: full || !chat.walkDone);
        fraction.value = share;
        // Posts of songs already listed, such as the bot's own copies, are read but not new.
        final counts = '${seen.length} songs read, $added new';
        progress.value = share == null
            ? 'Checking ${chat.title}: $counts'
            : 'Syncing ${chat.title}: ${min(next, knownEnd) ~/ messageIdStep} of '
                '${knownEnd ~/ messageIdStep} messages, $counts';
        if (messages.isNotEmpty || next <= knownEnd) {
          empties = 0;
        } else if (++empties >= emptyLimit) {
          break;
        }
        // The chosen rate, stretched while Telegram is asking us to slow down.
        await Future<void>.delayed(gap(Work.reading) * (_walkPause.inMilliseconds / 3000));
      }
      await (_db.update(_db.libraryChats)..where((c) => c.id.equals(chat.id))).write(
        LibraryChatsCompanion(lastScannedMessageId: Value(newest), walkDone: const Value(true)),
      );
      if (!full) _caughtUp.add(chat.id);
      if (added > 0) onSongsAdded?.call();
      return seen;
    } on TdError catch (e) {
      progress.value = '${chat.title}: scan failed, $e';
      await Future<void>.delayed(gap(Work.reading));
      return null;
    } finally {
      progress.value = null;
      fraction.value = null;
    }
  }

  /// Waits out Telegram rate limits and tries again.
  Future<Json> _retrying(Future<Json> Function() request, {void Function()? onRateLimit}) async {
    while (true) {
      try {
        return await request();
      } on TdError catch (e) {
        final wait = e.retryAfter;
        if (wait == null) rethrow;
        onRateLimit?.call();
        progress.value = 'Telegram rate limit, waiting ${wait}s';
        await Future<void>.delayed(Duration(seconds: wait));
      }
    }
  }
}
