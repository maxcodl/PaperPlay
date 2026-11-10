import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../log.dart';
import '../telegram/bot_api.dart';
import '../telegram/td_client.dart';
import '../telegram/td_compat.dart';
import 'db.dart';
import 'scanner.dart';
import 'taste.dart';
import 'upload.dart';

enum MoveStatus { queued, moving, done, skipped, failed }

class MoveJob {
  MoveJob(this.song, this.topicId, this.topicName, {this.toChat, this.restore = false, this.fromTopic = generalTopicId});

  /// The topic it's moved out of: General when filing, another when a topic is emptied.
  final int fromTopic;
  final Song song;
  final int topicId;
  final String topicName;

  /// Another chat to copy it into, leaving the original where it is. Null moves it
  /// between topics of its own chat.
  final int? toChat;

  /// Posts it back into a chat it was copied from, whose own post is gone. The library
  /// keeps listing it where it is and only remembers the new post as a repeat.
  final bool restore;
  var status = MoveStatus.queued;
  var retries = 0;
  String? note;

  /// The original message, read just before reposting it.
  Json? original;

  /// Set once the repost is confirmed in the right topic. From then on only the
  /// original's deletion is left, so a retry must never post again.
  int? newMessageId;
}

class MoveProblem implements Exception {
  MoveProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Telegram refused to delete the original after the repost landed.
class DeleteRefused implements Exception {
  DeleteRefused(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sends [message]'s file again into [topicId], by remote id, so nothing is uploaded.
/// Audio stays audio and a file stays a file, with its caption. It's silent, since a
/// tidy-up shouldn't notify the group once per song. [toChat] sends it to another chat.
Json repostRequest(Json message, int topicId, {int? toChat}) {
  final content = message['content'] as Json;
  final payload = audioPayload(message)!;
  final file = {'@type': 'inputFileRemote', 'id': (payloadFile(payload)['remote'] as Json)['id']};
  final caption = content['caption'];
  return {
    '@type': 'sendMessage',
    'chat_id': toChat ?? message['chat_id'],
    ...topicField(topicId),
    'options': {'@type': 'messageSendOptions', 'disable_notification': true},
    'input_message_content': content['@type'] == 'messageAudio'
        ? audioContent(
            file,
            duration: payload['duration'],
            title: payload['title'],
            performer: payload['performer'],
            caption: caption,
          )
        : documentContent(file, caption: caption),
  };
}

/// Whether [sent] is really [uniqueId]'s file, in topic [topicId]. Anything else
/// means the original must stay. A null [topicId] means the topic doesn't matter.
bool repostFits(Json sent, String uniqueId, int? topicId) {
  final payload = audioPayload(sent);
  if (payload == null || (topicId != null && topicIdOf(sent) != topicId)) return false;
  return (payloadFile(payload)['remote'] as Json)['unique_id'] == uniqueId;
}

/// Moves songs out of General, since Telegram has no way to move a message between
/// topics: repost into the new topic, then delete the original only once the repost
/// is confirmed. One at a time, paced like uploads, which reduces the risk of
/// Telegram limiting the bot but can't rule it out. Stops at the first real failure.
class TopicMover {
  TopicMover(
    Future<Json> Function(Json) call,
    Stream<Json> updates,
    this._db, {
    this.isPlaying,
    BotApi? botApi,
    this.userDelete,
    this.bots,
    this.canWriteWith,
    Future<void> Function(Duration)? sleep,
    Random? random,
  })  : _mainCall = call,
        _mainUpdates = updates,
        _botApi = botApi,
        _sleep = sleep ?? Future<void>.delayed,
        _random = random ?? Random();

  /// Asked when TDLib refuses a delete from cached information.
  final BotApi? _botApi;

  /// The owner's own account, if they logged it in: deletes what the bot isn't allowed
  /// to, such as posts older than 48 hours. Null, or false back, when it can't.
  final Future<bool> Function(int chat, int message)? userDelete;
  bool Function() hasUser = () => false;

  /// Deletes, through the owner's account, the old posts the bot was refused. Their
  /// songs were already copied, so the library only drops the old post.
  Future<int> retryRefused() async {
    await _loadRefused();
    // Also old General posts from before refusals were remembered: a repeat in General
    // of a song that already sits in a topic of the main chat.
    final main = await _db.mainChatId();
    if (main != null) {
      for (final c in await (_db.select(_db.postCopies)..where((c) => c.chatId.equals(main))).get()) {
        if (c.topicId != null && c.topicId != generalTopicId) continue;
        final row = await _db.songByUniqueId(c.uniqueId);
        final topic = row?.topicId;
        if (row == null || row.chatId != main || topic == null || topic == generalTopicId) continue;
        _refused.add((c.chatId, c.messageId));
      }
    }
    var done = 0;
    for (final k in [..._refused]) {
      if (await userDelete?.call(k.$1, k.$2) != true) continue;
      await _db.removePost(k.$1, k.$2, preferChat: k.$1);
      _refused.remove(k);
      done++;
    }
    await _db.setPref(_refusedKey, jsonEncode([for (final k in _refused) [k.$1, k.$2]]));
    if (done > 0) {
      _refusals = 0;
      deleteBlocked.value = false;
    }
    return done;
  }
  final Future<Json> Function(Json) _mainCall;
  final Stream<Json> _mainUpdates;
  final AppDb _db;

  /// Extra bots that can take a move (the main bot is the one `call` talks to). Each does the
  /// whole move itself, since a file id only means something to the bot that holds it.
  final List<TdClient> Function()? bots;
  final Future<bool> Function(TdClient bot, int chat)? canWriteWith;

  /// The bot working on the current move; null is the main bot. Moves run one at a time.
  TdClient? _bot;
  Future<Json> Function(Json) get _call => _bot?.call ?? _mainCall;
  Stream<Json> get _updates => _bot?.updates ?? _mainUpdates;

  final _botFlood = <TdClient?, DateTime>{};
  var _turn = 0;

  /// The next bot in turn for a move in [chat], waiting if every bot has been told to.
  Future<TdClient?> _pickBot(int chat) async {
    var eligible = await _eligible(chat);
    while (eligible.isEmpty) {
      final soonest = _botFlood.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b);
      await _wait(soonest.value.difference(DateTime.now()) + const Duration(seconds: 1));
      _botFlood.remove(soonest.key);
      eligible = await _eligible(chat);
    }
    return eligible[_turn++ % eligible.length];
  }

  /// Bots that may work in [chat] now: the main bot (null) and each extra bot that is an
  /// admin there and hasn't been told to wait.
  Future<List<TdClient?>> _eligible(int chat) async {
    final now = DateTime.now();
    final mainWait = _botFlood[null];
    final out = <TdClient?>[if (mainWait == null || !mainWait.isAfter(now)) null];
    for (final b in bots?.call() ?? const <TdClient>[]) {
      final wait = _botFlood[b];
      if (wait != null && wait.isAfter(now)) continue;
      if (await (canWriteWith?.call(b, chat) ?? Future.value(false))) out.add(b);
    }
    return out;
  }
  final Future<void> Function(Duration) _sleep;
  final Random _random;

  /// A song being played is left where it is: its row would change under the player.
  final bool Function(Song)? isPlaying;

  static const _maxRateLimitRetries = 5;
  static const _sendTimeout = Duration(minutes: 2);

  final jobs = ValueNotifier<List<MoveJob>>([]);
  final nextAt = ValueNotifier<DateTime?>(null);
  final paused = ValueNotifier(false);

  /// Why it stopped by itself.
  final problem = ValueNotifier<String?>(null);

  /// The bot can't delete posts here. Moves out of General then wait, since each would
  /// leave a second copy behind, while copies into the chat carry on.
  final deleteBlocked = ValueNotifier(false);

  void allowDeletesAgain() {
    deleteBlocked.value = false;
    _refused.clear();
    _refusals = 0;
    unawaited(_db.setPref(_refusedKey, '[]'));
  }

  static const _refusedKey = 'delete_refused';
  var _refusedLoaded = false;

  /// Kept across restarts, or each run would repost the same few and leave more copies.
  Future<void> _loadRefused() async {
    if (_refusedLoaded) return;
    _refusedLoaded = true;
    try {
      for (final v in jsonDecode(await _db.pref(_refusedKey) ?? '[]') as List) {
        _refused.add(((v as List)[0] as int, v[1] as int));
      }
    } on FormatException {
      // Starts empty.
    }
  }

  /// Posts Telegram refused to delete (old or pre-upgrade posts, say). They stay put, and
  /// the rest carry on. Only repeated refusals with no delete working in between block all.
  final _refused = <(int, int)>{};
  var _refusals = 0;

  var _moved = 0;
  var _pumping = false;

  bool get active => jobs.value.any((j) => j.status == MoveStatus.queued || j.status == MoveStatus.moving);

  void _changed() => jobs.value = [...jobs.value];

  /// Only call after the owner has confirmed exactly these moves.
  void start(List<MoveJob> moves) {
    jobs.value = [...(active ? jobs.value : const <MoveJob>[]), ...moves];
    paused.value = false;
    problem.value = null;
    unawaited(_pump());
  }

  void setPaused(bool value) {
    paused.value = value;
    if (!value) {
      problem.value = null;
      unawaited(_pump());
    }
  }

  /// Drops what's still waiting. A song mid-move finishes, so it's never left half done.
  void cancel() {
    jobs.value = jobs.value.where((j) => j.status != MoveStatus.queued).toList();
    paused.value = false;
  }

  Future<void> _wait(Duration d) async {
    nextAt.value = DateTime.now().add(d);
    await _sleep(d);
    nextAt.value = null;
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (!paused.value) {
        final job = jobs.value.where((j) => j.status == MoveStatus.queued).firstOrNull;
        if (job == null) return;
        job.status = MoveStatus.moving;
        _changed();
        // Copies from other chats stay with the main bot; a move can go to any bot that
        // is an admin in the chat.
        final worker = _bot = job.toChat != null ? null : await _pickBot(job.song.chatId);
        Duration? rateLimit;
        var acted = false;
        try {
          acted = await _moveOne(job);
          if (acted) {
            job.status = MoveStatus.done;
            _moved++;
          }
        } catch (e) {
          rateLimit = e is TdError ? _secondsOf(e.retryAfter) : retryAfterOf(e);
          if (rateLimit != null && job.retries < _maxRateLimitRetries) {
            job
              ..retries += 1
              ..status = MoveStatus.queued;
          } else if (e is DeleteRefused) {
            // Both posts are real, and the rest can carry on: only moves are held back.
            await _keepBoth(job, e);
            _refused.add((job.song.chatId, job.song.messageId));
            unawaited(_db.setPref(_refusedKey, jsonEncode([for (final k in _refused) [k.$1, k.$2]])));
            if (++_refusals >= 3) deleteBlocked.value = true;
            problem.value = job.note;
          } else {
            await _fail(job, e);
            return;
          }
        }
        _changed();
        if (rateLimit != null) {
          final wait = rateLimit + Duration(seconds: 5 + _random.nextInt(11));
          _botFlood[worker] = DateTime.now().add(wait);
          // Only when no other bot can carry on does everything wait.
          if ((await _eligible(job.song.chatId)).isEmpty) {
            await _wait(wait);
            _botFlood.remove(worker);
          }
        } else if (acted && jobs.value.any((j) => j.status == MoveStatus.queued)) {
          // Each bot has its own limit, so more bots can go proportionally faster.
          final n = max(1, (await _eligible(job.song.chatId)).length);
          final pause = uploadPause(_moved, _random);
          await _wait(Duration(microseconds: pause.inMicroseconds ~/ n));
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Duration? _secondsOf(int? seconds) => seconds == null ? null : Duration(seconds: seconds);

  /// Reposted but not deleted. Both posts are real, so the old one is listed as a copy.
  Future<void> _keepBoth(MoveJob job, Object error) async {
    final original = job.original;
    if (original != null) {
      final copy = songFromMessage(original);
      if (copy != null) await _db.upsertBotSong(copy);
    }
    job.note = 'Moved, but the old post in General couldn\'t be deleted: $error';
    job.status = MoveStatus.failed;
  }

  Future<void> _fail(MoveJob job, Object error) async {
    if (job.newMessageId != null && job.original != null) {
      await _keepBoth(job, error);
    } else {
      job.note = '$error Original kept.';
      job.status = MoveStatus.failed;
    }
    problem.value = job.note;
    paused.value = true;
    _changed();
  }

  /// The facts about a post that decide whether it can be deleted, for the log. Plain
  /// flags and ids only.
  String _describeMessage(Json m) => [
        'message_id=${m['id']}',
        'is_outgoing=${m['is_outgoing']}',
        'is_channel_post=${m['is_channel_post']}',
        'can_be_deleted_for_all_users=${m['can_be_deleted_for_all_users']}',
        'sender=${(m['sender_id'] as Map?)?['@type']}',
      ].join(' ');

  /// TDLib's answer, and when it's no, Telegram's own. TDLib decides from what it has
  /// cached, which can be out of date, so a no from it isn't final.
  Future<bool> _mayDelete(Json message) async {
    if (await _canDelete(message)) return true;
    final real = await _botApi?.canDelete(message['chat_id'] as int);
    if (real == true) {
      logEvent('filing', 'TDLib says the bot can\'t delete here, but Telegram says it can: using Telegram directly');
    }
    return real == true;
  }

  /// Whether Telegram lets the bot delete this post, asked before reposting it. Reposting
  /// first would leave a second copy behind. Unknown counts as yes: a refused delete is
  /// still handled afterwards.
  Future<bool> _canDelete(Json message) async {
    final direct = message['can_be_deleted_for_all_users'];
    if (direct is bool) return direct;
    try {
      final properties = await _call({
        '@type': 'getMessageProperties',
        'chat_id': message['chat_id'],
        'message_id': message['id'],
      });
      final known = properties['can_be_deleted_for_all_users'];
      if (known is bool) return known;
    } on TdError {
      // This TDLib may not offer it.
    }
    return true;
  }

  /// The post, read by the bot working on this move or, when that one can't see it, by the
  /// one that can: a bot can't read another bot's posts. The bot that read it does the move.
  Future<Json> _readOriginal(int chat, int messageId) async {
    final request = {'@type': 'getMessage', 'chat_id': chat, 'message_id': messageId};
    try {
      return await _call(request);
    } on TdError catch (e) {
      if (e.code != 404) rethrow;
      for (final other in [null, ...?bots?.call()]) {
        if (other == _bot) continue;
        try {
          final found = await (other?.call ?? _mainCall)(request);
          _bot = other;
          return found;
        } on TdError {
          // Not this one either.
        }
      }
      rethrow;
    }
  }

  /// False if the song was left alone without contacting Telegram for a post.
  Future<bool> _moveOne(MoveJob job) async {
    if (job.toChat != null) return _copyOne(job, job.toChat!);
    final chat = job.song.chatId, oldId = job.song.messageId;
    if (job.newMessageId == null) {
      final song = await _db.song(chat, oldId);
      String? skip;
      if (song == null) {
        skip = 'No longer in the library';
      } else if (song.topicId != generalTopicId) {
        skip = 'Not in General any more';
      } else if (job.topicId == generalTopicId) {
        skip = 'Already in General';
      } else if (isPlaying?.call(song) ?? false) {
        skip = 'Playing now, so left in General. Run it again later.';
      }
      if (skip != null) {
        job
          ..status = MoveStatus.skipped
          ..note = skip;
        return false;
      }

      // Asks Telegram, since the library can be behind what's really in the chat.
      final original = await _readOriginal(chat, oldId);
      if (topicIdOf(original) != job.fromTopic) {
        job
          ..status = MoveStatus.skipped
          ..note = 'Telegram says it\'s not in that topic any more';
        return false;
      }
      if (audioPayload(original) == null) throw MoveProblem('That post no longer holds a song.');
      job.original = original;
      await _loadRefused();
      final user = hasUser();
      if (!user && (deleteBlocked.value || _refused.contains((chat, oldId)) || !await _mayDelete(original))) {
        logEvent('filing', 'Not moved, delete not allowed: ${_describeMessage(original)}', level: LogLevel.warning);
        if (!_refused.contains((chat, oldId))) deleteBlocked.value = true;
        job
          ..status = MoveStatus.skipped
          ..note = 'The bot can\'t delete posts here, so this stays in General.';
        return false;
      }

      final sent = await _repost(repostRequest(original, job.topicId));
      if (!repostFits(sent, song!.uniqueId, job.topicId)) {
        final stray = songFromMessage(sent);
        if (stray != null) await _db.upsertBotSong(stray);
        throw MoveProblem('The repost didn\'t land in ${job.topicName} as expected, so nothing was deleted.');
      }
      await _db.movePostTo(
        song,
        messageId: sent['id'] as int,
        remoteId: (payloadFile(audioPayload(sent)!)['remote'] as Json)['id'] as String,
        topicId: job.topicId,
      );
      job.newMessageId = sent['id'] as int;
      // The main bot can't read a post another bot made, so a scan mustn't read its absence as a delete.
      if (_bot != null) await _db.markExtraBotPost(chat, sent['id'] as int);
    }
    try {
      await _call({'@type': 'deleteMessages', 'chat_id': chat, 'message_ids': [oldId], 'revoke': true});
      _refusals = 0;
    } on TdError catch (e) {
      // A rate limit is waited out and retried; anything else won't change by asking again.
      if (e.code == 429) rethrow;
      // TDLib refused from what it has cached. Telegram itself has the final say.
      final why = await _botApi?.deleteMessage(chat, oldId);
      if (_botApi != null && why == null) {
        logEvent('filing', 'TDLib refused the delete, but Telegram accepted it');
        _refusals = 0;
        return true;
      }
      if (await userDelete?.call(chat, oldId) == true) {
        logEvent('filing', 'The bot was refused, so your account deleted the old post');
        _refusals = 0;
        return true;
      }
      logEvent(
        'filing',
        'Delete refused: ${e.code} ${e.message}${why == null ? '' : ', Telegram says: $why'}. '
        '${_describeMessage(job.original ?? const {})}',
        level: LogLevel.warning,
      );
      throw DeleteRefused(why ?? e.message);
    }
    return true;
  }

  /// Posts a song into another chat and lists it there. The original stays in its
  /// channel, remembered as a repeat of the file.
  Future<bool> _copyOne(MoveJob job, int toChat) async {
    final song = await _db.songByUniqueId(job.song.uniqueId);
    String? skip;
    if (song == null) {
      skip = 'No longer in the library';
    } else if (song.chatId == toChat) {
      skip = 'Already there';
    } else if (isPlaying?.call(song) ?? false) {
      skip = 'Playing now. It\'s filed later.';
    }
    if (skip != null) {
      job
        ..status = MoveStatus.skipped
        ..note = skip;
      return false;
    }
    final original = await _call({'@type': 'getMessage', 'chat_id': song!.chatId, 'message_id': song.messageId});
    if (audioPayload(original) == null) throw MoveProblem('That post no longer holds a song.');
    final sent = await _repost(repostRequest(original, job.topicId, toChat: toChat));
    final topic = job.topicId == generalTopicId ? null : job.topicId;
    if (!repostFits(sent, song.uniqueId, topic)) {
      final stray = songFromMessage(sent);
      if (stray != null) await _db.upsertBotSong(stray);
      throw MoveProblem('The copy didn\'t land in ${job.topicName} as expected. Original kept.');
    }
    if (job.restore) {
      // The song is listed under its main chat post, so this is remembered as another post of it.
      final back = songFromMessage(sent);
      if (back != null) await _db.upsertBotSong(back);
      return true;
    }
    await _db.listAtCopy(
      song,
      chatId: toChat,
      messageId: sent['id'] as int,
      remoteId: (payloadFile(audioPayload(sent)!)['remote'] as Json)['id'] as String,
      topicId: topicIdOf(sent),
    );
    return true;
  }

  /// Sends, and waits for Telegram to confirm. Throws if it refuses or stays silent.
  Future<Json> _repost(Json request) async {
    final early = <Json>[];
    int? temporary;
    final outcome = Completer<Json>();
    final sub = _updates.listen((u) {
      final type = u['@type'];
      if (type != 'updateMessageSendSucceeded' && type != 'updateMessageSendFailed') return;
      if (temporary == null) {
        early.add(u);
      } else if (u['old_message_id'] == temporary && !outcome.isCompleted) {
        outcome.complete(u);
      }
    });
    try {
      final pending = await _call(request);
      if (pending['sending_state'] == null) return pending;
      temporary = pending['id'] as int;
      for (final u in early) {
        if (u['old_message_id'] == temporary && !outcome.isCompleted) outcome.complete(u);
      }
      final Json update;
      try {
        update = await outcome.future.timeout(_sendTimeout);
      } on TimeoutException {
        throw MoveProblem('Telegram didn\'t confirm the repost in time, so nothing was deleted. '
            'If it arrives later, it shows up in Find duplicates.');
      }
      if (update['@type'] == 'updateMessageSendFailed') {
        final error = update['error'] as Json;
        throw TdError(error['code'] as int, error['message'] as String);
      }
      return update['message'] as Json;
    } finally {
      await sub.cancel();
    }
  }
}
