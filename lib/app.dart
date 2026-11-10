import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:drift/drift.dart' show BooleanExpressionOperators, InsertMode, Value;
import 'package:flutter/material.dart' show AppLifecycleState, Brightness, ThemeMode, ValueNotifier, WidgetsBinding;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'activity.dart';
import 'background.dart';
import 'library/auto_filer.dart';
import 'library/backup.dart';
import 'library/db.dart';
import 'library/delete_job.dart';
import 'library/duplicates.dart';
import 'library/mood.dart';
import 'library/playlist_import.dart';
import 'library/scanner.dart';
import 'library/spotify_account.dart';
import 'stats/listenbrainz.dart';
import 'library/taste.dart';
import 'library/throttle.dart';
import 'library/topic_mover.dart';
import 'library/upload.dart';
import 'library/weather.dart';
import 'log.dart';
import 'metadata/enricher.dart';
import 'pace.dart';
import 'sync/library_sync.dart' show markSongGone, markSongKeyGone;
import 'tasks.dart';
import 'telegram/user_session.dart';
import 'playback/cache.dart';
import 'playback/audio_outputs.dart';
import 'playback/media_session.dart';
import 'playback/player.dart';
import 'sync/device_link.dart';
import 'telegram/bot_api.dart';
import 'telegram/bot_pool.dart';
import 'telegram/channels.dart';
import 'telegram/td_client.dart';
import 'telegram/td_compat.dart';
import 'ui/cover_colors.dart';
import 'ui/ui_prefs.dart';

/// App-wide services, built once in main().
final class Services {
  final td = TdClient();
  final db = AppDb();
  late final scanner = Scanner(td, db);
  late final cache = CacheManager(td, db, pool: pool);
  late final player = PlayerController(td, db, cache);
  late final enricher = Enricher(td, db);
  late final pool = BotPool(td);
  late final uploader = Uploader(td, db, pool: pool)
    ..canWriteWith = botIsAdminWith
    ..onSentByExtraBot = ((u) {
      final m = u['message'] as Json?;
      if (m != null) unawaited(db.markExtraBotPost(m['chat_id'] as int, m['id'] as int));
      scanner.ingest(u);
    });
  /// Telegram's own answer on deleting, for when TDLib's cached view says no.
  late final botApi = BotApi(loadBotToken);
  late final userSession = UserSession(db);

  /// Another device asking to sign in through this one; the home screen asks the owner.
  final qrRequests = ValueNotifier<({String device, String link})?>(null);
  late final mover = TopicMover(
    td.call,
    td.updates,
    db,
    isPlaying: (s) => player.current.value?.uniqueId == s.uniqueId,
    botApi: botApi,
    userDelete: userSession.delete,
    bots: () => pool.ready.where((b) => b != td).toList(),
    canWriteWith: botIsAdminWith,
  )..hasUser = (() => userSession.loggedIn.value);
  late final filer = AutoFiler(
    db,
    TopicMover(td.call, td.updates, db,
        isPlaying: (s) => player.current.value?.uniqueId == s.uniqueId,
        botApi: botApi,
        userDelete: userSession.delete,
        bots: () => pool.ready.where((b) => b != td).toList(),
        canWriteWith: botIsAdminWith)
      ..hasUser = (() => userSession.loggedIn.value),
    mainChat: () => mainChat.value,
    topicNames: () => taste.value.topicNames,
    lookupsOn: () => taste.value.lookups,
    canDelete: canDeleteIn,
    createTopic: _createTopic,
    canWrite: botIsAdminIn,
  );

  static String? _foundNew(String? sync) =>
      sync == null || RegExp(r'(^|\D)0 new$').hasMatch(sync) ? null : sync;

  var _checkToastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// A toast when channel checking starts, at most every 10 minutes.
  void _toastChecking() {
    final now = DateTime.now();
    if (scanner.progress.value == null || now.difference(_checkToastAt) < const Duration(minutes: 10)) return;
    _checkToastAt = now;
    failureToast.add('Checking your channels for new songs');
  }

  /// Deletes a topic of the main chat but keeps its songs: each is moved to General
  /// first (reposted, checked, old post deleted), and the topic goes once it's empty.
  /// Its name is remembered so filing doesn't make it again. Returns a problem, or null.
  Future<String?> deleteTopicKeepSongs(ForumTopic t) async {
    final songs = await (db.select(db.songs)
          ..where((s) => s.chatId.equals(t.chatId) & s.topicId.equals(t.topicId)))
        .get();
    final gone = {...?(jsonDecode(await db.pref(_deletedTopicsKey) ?? '[]') as List?)?.cast<String>()};
    await db.setPref(_deletedTopicsKey, jsonEncode([...gone, t.name.toLowerCase()]));
    final jobs = [for (final s in songs) MoveJob(s, generalTopicId, 'General', fromTopic: t.topicId)];
    if (jobs.isNotEmpty) {
      mover.start(jobs);
      while (jobs.any((j) => j.status == MoveStatus.queued || j.status == MoveStatus.moving)) {
        if (mover.paused.value) return 'Moving stopped: ${mover.problem.value ?? 'paused'}. The topic was kept.';
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      final stuck = jobs.where((j) => j.status != MoveStatus.done).length;
      if (stuck > 0) return "$stuck songs couldn't be moved, so the topic was kept.";
    }
    try {
      await td.call(deleteForumTopicRequest(t.chatId, t.topicId));
    } on TdError catch (e) {
      return "The songs are in General now, but Telegram wouldn't delete the topic: ${e.message}";
    }
    await (db.delete(db.forumTopics)
          ..where((r) => r.chatId.equals(t.chatId) & r.topicId.equals(t.topicId)))
        .go();
    logEvent('filing', 'Deleted the topic ${t.name}; its ${songs.length} songs are in General');
    return null;
  }

  static const _deletedTopicsKey = 'topics_deleted';

  /// Topic names deleted here, which filing won't make again.
  Future<Set<String>> deletedTopics() async =>
      {...?(jsonDecode(await db.pref(_deletedTopicsKey) ?? '[]') as List?)?.cast<String>()};

  /// Topic colours Telegram allows, picked by name so each topic keeps its own.
  static const _topicColors = [7322096, 16766590, 13338331, 9367192, 16749490, 16478047];

  /// The bot makes a topic (needs the "Manage topics" right) and it's listed right away.
  Future<bool> _createTopic(int chat, String name) async {
    if ((await deletedTopics()).contains(name.toLowerCase())) return false;
    try {
      final info = await td.call({
        '@type': 'createForumTopic',
        'chat_id': chat,
        'name': name,
        'icon': {
          '@type': 'forumTopicIcon',
          'color': _topicColors[name.codeUnits.fold(0, (a, b) => a + b) % _topicColors.length],
          'custom_emoji_id': '0',
        },
      });
      final id = (info['forum_topic_id'] ?? info['message_thread_id']) as int?;
      if (id == null) return false;
      await db.into(db.forumTopics).insert(
            ForumTopicsCompanion.insert(chatId: chat, topicId: id, name: name),
            mode: InsertMode.insertOrIgnore,
          );
      logEvent('filing', 'Made the topic $name');
      return true;
    } on TdError catch (e) {
      logEvent('filing', 'Couldn\'t make the topic $name: ${e.message}', level: LogLevel.warning);
      return false;
    }
  }
  late final ui = UiPrefs(db);
  late final background = Background(db, player, activity: activity);

  /// Library counts, kept for [activity] and for the banner.
  final stats = ValueNotifier<LibraryStats?>(null);
  final moodScanned = ValueNotifier(0);

  /// What the app is busy with right now, for the notification, the tray and the banner.
  ActivitySummary activity() {
    final s = stats.value;
    final moves = [...mover.jobs.value, ...filer.mover.jobs.value];
    bool open(MoveJob j) => j.status == MoveStatus.queued || j.status == MoveStatus.moving;
    final uploads = uploader.jobs.value;
    bool uploading(UploadJob j) => j.status == UploadStatus.queued || j.status == UploadStatus.uploading;
    final total = s?.total ?? 0;
    return summarizeActivity(
      ActivityInputs(
        // Checking channels is only worth a bar once it finds songs; a toast says it started.
        sync: _foundNew(scanner.progress.value),
        syncFraction: scanner.fraction.value,
        movesDone: moves.where((j) => !open(j)).length,
        movesTotal: moves.length,
        movesPaused: (mover.paused.value || filer.mover.paused.value) && moves.any(open),
        uploadsDone: uploads.where((j) => !uploading(j)).length,
        uploadsTotal: uploads.length,
        uploadsPaused: uploader.paused.value && uploads.any(uploading),
        infoLeft: s?.waiting ?? 0,
        infoTotal: total,
        infoRunning: enricher.run.value == EnrichRun.running,
        infoPaused: enricher.run.value == EnrichRun.paused,
        coversLeft: enricher.coversQueued.value,
        coversBatch: enricher.coversBatch.value,
        scanLeft: taste.value.lookups ? max(0, total - moodScanned.value) : 0,
        scanTotal: total,
      ),
    );
  }
  late final link = DeviceLink(
    db,
    player,
    onNewChats: _scanNewChats,
    afterMerge: () async {
      await reconcileImports(db);
      await tasks.reloadHistory();
    },
    saveCover: enricher.saveChosenCover,
    onTasteChanged: () async {
      await loadTaste();
      await loadMainChat();
    },
    onStatus: (s) => scanner.progress.value = s,
  )
    ..postsExist = _postsExist
    ..onRemoteTasks = ((id, name, runs) => tasks.onRemote(id, name, runs))
    ..onStopTask = ((kind) => tasks.stop(kind));

  /// Running and past tasks, here and on other devices.
  late final tasks = TaskCenter(this);

  /// The chat songs get filed into. Shared between devices.
  final mainChat = ValueNotifier<int?>(null);

  Future<void> loadMainChat() async => mainChat.value = await db.mainChatId();

  Future<void> setMainChat(int? id) async {
    await db.setMainChat(id);
    mainChat.value = id;
    // Whoever chooses the main chat does the posting, unless they turn it off.
    if (id != null) await db.setPref('file_here', 'true');
    filer.kick();
  }
  late final mediaSession = MediaSession(player);
  late final sound = SoundOutputs(db);
  late final weather = WeatherService(db);
  late final spotify = SpotifyAccount(db);
  late final listenbrainz = ListenBrainz(db);

  /// The library as it is now, by unique id. Screens that keep a song for a while,
  /// like Home's rows and queues, look here so they never show an old cover.
  final liveSongs = ValueNotifier<Map<String, Song>>(const {});

  /// The current version of [s].
  Song fresh(Song s) => liveSongs.value[s.uniqueId] ?? s;

  /// What mixes may learn from. Shared between devices.
  final taste = ValueNotifier(const TasteSettings());

  Future<void> loadTaste() async => taste.value = await db.tasteSettings();

  Future<void> setTaste(TasteSettings t) async {
    final wasOff = !taste.value.lookups;
    final next = t.copyWith(at: DateTime.now().millisecondsSinceEpoch);
    taste.value = next;
    await db.saveTasteSettings(next);
    if (wasOff && next.lookups) unawaited(enricher.scanMoods());
  }

  Future<void> setTasteSource(String key, bool on) =>
      setTaste(taste.value.copyWith(sources: {...taste.value.sources, key: on}));

  Future<void> clearLearning() async {
    await db.clearLearnedData(DateTime.now().millisecondsSinceEpoch);
    await loadTaste();
  }

  /// The lists mixes learn from right now.
  Future<List<TasteList>> tasteLists() async {
    final t = taste.value;
    final byKey = {for (final s in await db.select(db.songs).get()) (s.chatId, s.messageId): s.uniqueId};
    final lists = <TasteList>[];
    if (t.learnsFrom(TasteSettings.favoritesKey)) {
      final fav = await (db.select(db.songs)..where((s) => s.favorite.equals(true))).get();
      lists.add(TasteList('Favorites', {for (final s in fav) s.uniqueId}));
    }
    final entries = await (db.select(db.playlistSongs)..where((r) => r.removedAt.isNull())).get();
    for (final p in await db.livePlaylists()) {
      if (!t.learnsFrom(TasteSettings.playlistKey(p.uuid))) continue;
      lists.add(TasteList(p.name, {
        for (final e in entries)
          if (e.playlistId == p.id && byKey[(e.chatId, e.messageId)] != null) byKey[(e.chatId, e.messageId)]!,
      }));
    }
    for (final topic in await db.select(db.forumTopics).get()) {
      final key = TasteSettings.topicKey(topic.chatId, topic.topicId);
      if (!t.learnsFrom(key)) continue;
      final songs = await db.watchTopicSongs(topic.chatId, topic.topicId).first;
      lists.add(TasteList(t.topicNames[key] ?? topic.name, {for (final s in songs) s.uniqueId}));
    }
    return lists;
  }

  /// Forgets a channel on every device. Nothing changes in Telegram, so it can be added
  /// again. Songs also in the main chat carry on from there.
  Future<void> removeChannel(int chatId) async {
    if (chatId == mainChat.value) return;
    // While its songs are still listed, so their saved files can be found.
    if (td.started) await cache.removeChatFiles(chatId);
    await db.removeChat(chatId, preferChat: mainChat.value);
    await db.markChat(chatId, gone: true);
    logEvent('channels', 'Removed channel $chatId');
  }

  /// Whether the bot may delete posts in [chatId].
  Future<bool> canDeleteIn(int chatId) async {
    final group = supergroupIdOf(chatId);
    if (group == null) return false;
    try {
      final info = await td.call({'@type': 'getSupergroup', 'supergroup_id': group});
      final status = info['status'] as Json;
      final can = status['@type'] == 'chatMemberStatusCreator' ||
          (status['@type'] == 'chatMemberStatusAdministrator' &&
              (status['rights'] as Json)['can_delete_messages'] == true);
      logEvent(
        'filing',
        'Bot rights in $chatId: ${status['@type']} can_delete_messages='
        '${(status['rights'] as Map?)?['can_delete_messages']} is_channel=${info['is_channel']}',
      );
      return can;
    } on TdError {
      return false;
    }
  }

  final _adminSeen = <(int, int), (bool, DateTime)>{};

  /// Whether this device's bot is an admin (or owner) of [chatId]. The app only ever
  /// writes where it is: in a chat someone else added it to without admin rights, it
  /// just reads, so two people's libraries never mix. Remembered for 10 minutes.
  Future<bool> botIsAdminIn(int chatId) => botIsAdminWith(td, chatId);

  /// The same for any bot in the pool. An extra bot may not know the chat yet, so it asks for it first.
  Future<bool> botIsAdminWith(TdClient bot, int chatId) async {
    final key = (bot.slot, chatId);
    final seen = _adminSeen[key];
    if (seen != null && DateTime.now().difference(seen.$2) < const Duration(minutes: 10)) return seen.$1;
    var admin = false;
    try {
      if (bot != td) await bot.call({'@type': 'getChat', 'chat_id': chatId});
      final group = supergroupIdOf(chatId);
      final status = group != null
          ? (await bot.call({'@type': 'getSupergroup', 'supergroup_id': group}))['status'] as Json
          : (await bot.call({
              '@type': 'getChatMember',
              'chat_id': chatId,
              'member_id': {'@type': 'messageSenderUser', 'user_id': await bot.call({'@type': 'getMe'}).then((m) => m['id'])},
            }))['status'] as Json;
      admin = status['@type'] == 'chatMemberStatusCreator' || status['@type'] == 'chatMemberStatusAdministrator';
    } on TdError {
      admin = false;
    }
    _adminSeen[key] = (admin, DateTime.now());
    if (!admin) logEvent('filing', 'Read only in $chatId: ${bot.slot == 0 ? 'the bot' : 'extra bot ${bot.slot}'} isn\'t an admin there');
    return admin;
  }

  /// Permanently deletes a song from Telegram: its post and any repeats of the file.
  /// Returns how many posts went. Throws [TdError] if Telegram refuses.
  Future<int> deleteSong(Song s) async {
    final copies = await (db.select(db.postCopies)..where((c) => c.uniqueId.equals(s.uniqueId))).get();
    // Move on first, so the player isn't left reading a file that's gone.
    if (player.current.value?.uniqueId == s.uniqueId) await player.out.seekToNext();
    final byChat = <int, List<int>>{s.chatId: [s.messageId]};
    for (final c in copies) {
      (byChat[c.chatId] ??= []).add(c.messageId);
    }
    // Only the main chat is ever changed in Telegram, whatever kind of chat it is.
    // Posts elsewhere stay there and only leave the library.
    final main = mainChat.value;
    for (final e in byChat.entries) {
      if (e.key == main) await _deletePosts(e.key, e.value);
    }
    for (final c in copies) {
      await db.removePost(c.chatId, c.messageId);
    }
    await db.removePost(s.chatId, s.messageId);
    await markSongGone(db, s.uniqueId);
    await markSongKeyGone(db, goneKeyOf(s));
    db.announceChange();
    return copies.length + 1;
  }

  /// Which of [posts] still exist, asked of Telegram 100 at a time. A batch that can't be
  /// answered counts as not existing, so nothing is added on a guess; the next sync asks again.
  Future<Set<(int, int)>> _postsExist(List<(int, int)> posts) async {
    final byChat = <int, List<int>>{};
    for (final p in posts) {
      (byChat[p.$1] ??= []).add(p.$2);
    }
    final alive = <(int, int)>{};
    for (final e in byChat.entries) {
      for (var i = 0; i < e.value.length; i += 100) {
        final ids = e.value.sublist(i, min(i + 100, e.value.length));
        try {
          final r = await td.call({'@type': 'getMessages', 'chat_id': e.key, 'message_ids': ids}).timeout(const Duration(seconds: 30));
          final found = r['messages'] as List;
          for (var k = 0; k < ids.length && k < found.length; k++) {
            if (found[k] != null) alive.add((e.key, ids[k]));
          }
        } on TdError {
          // Not reachable by this bot.
        } on TimeoutException {
          // Offline.
        }
      }
    }
    return alive;
  }

  var _stopDeletes = false;

  /// Stops a bulk delete after the song being deleted now.
  void cancelDeletes() => _stopDeletes = true;

  /// Songs being deleted in bulk, for the Tasks page. Cleared when a new run starts.
  final deletions = ValueNotifier<List<DeleteJob>>([]);

  /// Deletes [songs] one by one, recording progress in [deletions]. Returns how many went.
  Future<int> deleteSongs(List<Song> songs) async {
    final jobs = [for (final s in songs) DeleteJob(s)];
    deletions.value = jobs;
    _stopDeletes = false;
    var done = 0;
    for (final j in jobs.toList()) {
      if (_stopDeletes) {
        jobs.remove(j);
        continue;
      }
      j.status = DeleteStatus.deleting;
      deletions.value = [...jobs];
      try {
        await deleteSong(j.song);
        j.status = DeleteStatus.done;
        done++;
      } on Exception catch (e) {
        j.status = DeleteStatus.failed;
        j.error = '$e';
      }
      deletions.value = [...jobs];
    }
    return done;
  }

  var _dupPumping = false;
  final _dupQueue = <(DuplicatePost, DuplicatePost, DeleteJob)>[];

  /// Queues repeated posts for deletion after the owner confirmed them. Runs here, not in
  /// the screen, so it carries on when the page is left, shows in Tasks and ends in
  /// batches of up to 100 posts. Each post goes after what points at it moves to its keeper.
  void deleteDuplicates(List<(DuplicatePost post, DuplicatePost keep)> pairs) {
    if (!_dupPumping && !deletions.value.any((j) => j.status == DeleteStatus.queued || j.status == DeleteStatus.deleting)) {
      deletions.value = [];
    }
    final added = <DeleteJob>[];
    for (final (post, keep) in pairs) {
      final song = post.song ?? keep.song;
      if (song == null) continue;
      final job = DeleteJob.duplicate(song,
          chat: post.chatId, message: post.messageId, keepChat: keep.chatId, keepMessage: keep.messageId);
      _dupQueue.add((post, keep, job));
      added.add(job);
    }
    deletions.value = [...deletions.value, ...added];
    _stopDeletes = false;
    if (!_dupPumping) unawaited(_pumpDuplicates());
  }

  Future<void> _pumpDuplicates() async {
    _dupPumping = true;
    try {
      while (_dupQueue.isNotEmpty) {
        if (_stopDeletes) {
          final dropped = {for (final e in _dupQueue) e.$3};
          _dupQueue.clear();
          deletions.value = [for (final j in deletions.value) if (!dropped.contains(j)) j];
          break;
        }
        final batch = _dupQueue.take(100).toList();
        _dupQueue.removeRange(0, batch.length);
        for (final e in batch) {
          e.$3.status = DeleteStatus.deleting;
        }
        deletions.value = [...deletions.value];
        await _deleteDuplicateBatch(batch);
        deletions.value = [...deletions.value];
      }
    } finally {
      _dupPumping = false;
    }
  }

  /// True if the post exists, false if Telegram says it doesn't, null if it couldn't be asked.
  Future<bool?> _postState(int chat, int message) async {
    for (var tries = 0; tries < 4; tries++) {
      try {
        await td.call({'@type': 'getMessage', 'chat_id': chat, 'message_id': message}).timeout(const Duration(seconds: 30));
        return true;
      } on TdError catch (e) {
        final wait = e.retryAfter;
        if (wait != null) {
          await Future<void>.delayed(Duration(seconds: wait + 1));
          continue;
        }
        return e.code == 404 || e.code == 400 ? false : null;
      } on TimeoutException {
        return null;
      }
    }
    return null;
  }

  Future<void> _deleteDuplicateBatch(List<(DuplicatePost, DuplicatePost, DeleteJob)> batch) async {
    final main = mainChat.value;
    // This device may not have heard that a kept post was moved or deleted; the only live
    // post of a song is never deleted as a "copy". One question per 100 keepers.
    final keepers = {for (final e in batch) (e.$2.chatId, e.$2.messageId)};
    final alive = await _postsExist(keepers.toList());
    // A batch that couldn't be answered (Telegram busy) also looks like "not there", so what
    // wasn't confirmed is asked about singly, waiting out a rate limit, before it is blamed.
    final unsure = <(int, int)>{};
    for (final k in keepers) {
      if (alive.contains(k)) continue;
      final state = await _postState(k.$1, k.$2);
      if (state == true) {
        alive.add(k);
      } else if (state == null) {
        unsure.add(k);
      }
    }
    final ok = <(DuplicatePost, DuplicatePost, DeleteJob)>[];
    for (final e in batch) {
      if (e.$1.chatId != main) {
        e.$3
          ..status = DeleteStatus.failed
          ..error = 'That post isn\'t in the main chat.';
      } else if (unsure.contains((e.$2.chatId, e.$2.messageId))) {
        e.$3
          ..status = DeleteStatus.failed
          ..error = "Couldn't check the post to keep (Telegram is busy). Nothing was deleted; try again.";
      } else if (!alive.contains((e.$2.chatId, e.$2.messageId))) {
        e.$3
          ..status = DeleteStatus.failed
          ..error = 'The post to keep is gone, so nothing was deleted.';
      } else {
        ok.add(e);
      }
    }
    final byChat = <int, List<(DuplicatePost, DuplicatePost, DeleteJob)>>{};
    for (final e in ok) {
      final loser = e.$1.song, keeper = e.$2.song;
      if (loser != null && keeper != null) await db.moveReferences(loser, keeper);
      (byChat[e.$1.chatId] ??= []).add(e);
    }
    for (final entry in byChat.entries) {
      var retries = 0;
      while (true) {
        try {
          final ids = [for (final e in entry.value) e.$1.messageId];
          final left = (await _deletePostsBest(entry.key, ids)).toSet();
          for (final e in entry.value) {
            if (left.contains(e.$1.messageId)) {
              e.$3
                ..status = DeleteStatus.failed
                ..error = userSession.loggedIn.value
                    ? "Telegram wouldn't let this post be deleted."
                    : 'Too old for the bot. Log in your account in Settings, Library.';
            } else {
              await db.removePost(e.$1.chatId, e.$1.messageId);
              e.$3.status = DeleteStatus.done;
            }
          }
          break;
        } on TdError catch (e) {
          final wait = e.retryAfter;
          if (wait != null && retries++ < 5) {
            await Future<void>.delayed(Duration(seconds: wait + 1));
            continue;
          }
          for (final d in entry.value) {
            d.$3
              ..status = DeleteStatus.failed
              ..error = '$e';
          }
          break;
        }
      }
    }
    db.announceChange();
  }

  /// Deletes posts through the bot, then Telegram's HTTP Bot API (TDLib can judge from
  /// stale rights), then the owner's account if logged in (bots can't delete old posts).
  Future<void> _deletePosts(int chatId, List<int> ids) async {
    final left = await _deletePostsBest(chatId, ids);
    if (left.isEmpty) return;
    throw TdError(
      400,
      userSession.loggedIn.value
          ? "Telegram wouldn't let this post be deleted."
          : "The bot can't delete posts older than 48 hours. Log in your account in Settings, Library, to allow it.",
    );
  }

  /// Deletes as many of [ids] as it can, in calls of up to 100 at each step, and returns
  /// the ones nobody could remove. Bot first, then the Bot API, then the owner's account.
  Future<List<int>> _deletePostsBest(int chatId, List<int> ids) async {
    try {
      await td.call({'@type': 'deleteMessages', 'chat_id': chatId, 'message_ids': ids, 'revoke': true});
      return const [];
    } on TdError catch (e) {
      if (e.code == 429) rethrow;
    }
    // TDLib refuses the whole call if one post can't go. Ask Telegram directly, which skips
    // those it can't delete, and see what is left.
    var left = ids;
    for (var i = 0; i < ids.length; i += 100) {
      await botApi.deleteMessages(chatId, ids.sublist(i, min(i + 100, ids.length)));
    }
    final alive = await _postsExist([for (final id in ids) (chatId, id)]);
    left = [for (final id in ids) if (alive.contains((chatId, id))) id];
    logEvent('delete', 'Bot refused ${ids.length}; the Bot API removed ${ids.length - left.length}, ${left.length} left'
        '${left.isEmpty ? '' : userSession.loggedIn.value ? ', asking your account' : ', your account is not logged in'}');
    if (left.isEmpty) return const [];
    final rest = await userSession.deleteBatch(chatId, left);
    logEvent('delete', 'Your account removed ${left.length - rest.length} of ${left.length}');
    return rest;
  }

  /// Counts Ctrl+F presses, for the home screen to open search.
  final searchRequests = ValueNotifier(0);

  /// Changes once the current cover's colours are ready, for the cover accent.
  late final coverAccentReady = _watchCoverAccent();

  ValueNotifier<int> _watchCoverAccent() {
    final ready = ValueNotifier(0);
    String? last;
    player.current.addListener(() async {
      final path = player.current.value?.coverPath;
      // The song's row changes for many other reasons; the whole app rebuilds on this.
      if (path == null || path == last) return;
      last = path;
      // Only the brightness in use: each one quantizes the image on the UI isolate. The
      // other is worked out when the theme switches and something asks for it.
      final mode = ui.themeMode.value;
      final dark = mode == ThemeMode.dark ||
          (mode == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
      await coverScheme(path, dark ? Brightness.dark : Brightness.light);
      if (ui.accent.value == accentCover) ready.value++;
    });
    return ready;
  }

  /// A bot and at least one channel are set up, so the library can open.
  final libraryReady = ValueNotifier(false);

  /// Why the bot couldn't log in, if it couldn't.
  final botError = ValueNotifier<String?>(null);

  String? _deviceId;

  /// This device and every connected one, in a fixed order, for splitting the work.
  static final _isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Background lookups on a phone only run while the app is open or the phone charges, so
  /// a phone in a pocket isn't kept busy. Checked again every minute. A PC is never held.
  Future<void> workGate() async {
    if (_isDesktop) return;
    while (true) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;
      if (await background.charging() == true) return;
      await Future<void>.delayed(const Duration(minutes: 1));
    }
  }

  /// Whether a PC is connected, which then does the heavy background work for a phone.
  bool get pcConnected => link.devices.value.any((p) => p.desktop);

  /// Heavy work (song info, covers, lyrics and mood scans) belongs to PCs when one is
  /// connected: a phone then only plays and receives results through the sync. With no PC
  /// connected, or between PCs, devices split the work as before.
  List<String> _ring() {
    final peers = link.devices.value;
    final ids = (_isDesktop || peers.any((p) => p.desktop))
        ? [if (_isDesktop) ?_deviceId, ...peers.where((p) => p.desktop).map((p) => p.id)]
        : [?_deviceId, ...peers.map((p) => p.id)];
    return ids..sort();
  }

  /// Whether this device is the one to do the work on a song. Linked devices split the
  /// library between them by a hash of the song, so each does its share and none repeats
  /// another's; results reach the others through the sync. Alone, a device owns everything.
  bool ownsSong(String uniqueId) {
    final mine = _deviceId;
    if (mine == null) {
      unawaited(db.pref('device_id').then((id) => _deviceId = id));
      return true;
    }
    // A phone with a PC connected leaves the work to it. It takes it back if the PC leaves.
    if (!_isDesktop && pcConnected) return false;
    final ring = _ring();
    // Alone in the ring until the other device has connected: the first check is early.
    return ring.length < 2 || stableHash(uniqueId) % ring.length == ring.indexOf(mine);
  }

  /// What reading song lengths is doing now, for the Tasks page.
  final lengthWork = ValueNotifier<({int done, int total, String title, String stage, double? fraction})?>(null);

  var _learningLengths = false;
  var _lengthsWaited = false;
  final _lengthTried = <String>{};

  /// Songs posted with no length get it from the file itself, one at a time, once each
  /// per run of the app. Without a length no online match is trusted, so no cover came.
  /// Each connected device takes its own share of the songs.
  Future<void> learnLengths() async {
    if (_learningLengths) return;
    _learningLengths = true;
    try {
      // Other devices need a moment to connect, or each would start on every song.
      if (!_lengthsWaited) {
        _lengthsWaited = true;
        await Future<void>.delayed(const Duration(seconds: 20));
      }
      _deviceId ??= await db.pref('device_id');
      // Files whose length couldn't be read are remembered, so they aren't downloaded again
      // every time the app starts.
      final unreadable = {...?(jsonDecode(await db.pref('length_unreadable') ?? '[]') as List?)?.cast<String>()};
      final songs = (await (db.select(db.songs)
                ..where((s) => s.durationSec.equals(0) & s.userEdited.equals(false)))
              .get())
          .where((s) => !_lengthTried.contains(s.uniqueId) && !unreadable.contains(s.uniqueId))
          .toList();
      var found = 0, handled = 0;
      final mine = songs.where((s) => ownsSong(s.uniqueId)).length;
      for (final s in songs) {
        // Asked for each song, so a device that connects midway takes its share from here on.
        if (!ownsSong(s.uniqueId) || !_lengthTried.add(s.uniqueId)) continue;
        void stage(String what, double? fraction) =>
            lengthWork.value = (done: handled, total: mine, title: s.title, stage: what, fraction: fraction);
        stage('Waiting', null);
        if (await cache.learnDuration(s, onStage: stage) != null) {
          found++;
        } else if (cache.lastLengthUnreadable) {
          unreadable.add(s.uniqueId);
          await db.setPref('length_unreadable', jsonEncode(unreadable.toList()));
        }
        handled++;
        await Future<void>.delayed(gap(Work.reading));
      }
      if (found > 0) {
        logEvent('metadata', 'Read the length of $found songs from their files');
        enricher.kick();
      }
    } catch (e) {
      logEvent('metadata', 'Reading song lengths stopped (${e.runtimeType})', level: LogLevel.warning);
    } finally {
      lengthWork.value = null;
      _learningLengths = false;
    }
  }

  var _wired = false;
  var _sync = Future<void>.value();

  Future<void> start() async {
    if (_wired) return;
    _wired = true;
    scanner.onSongsAdded = () {
      enricher.kick();
      _reconcileSoon();
      filer.kick();
    };
    player.onDurationLearned = enricher.kick;
    player.onScrobble = listenbrainz.scrobble;
    player.onSongStarted = (song) {
      unawaited(listenbrainz.nowPlaying(song));
      enricher.upgradeCover(song);
      // Long enough for the start of the file to have arrived. Then what the file itself
      // says fills the gaps the online lookups left.
      Timer(const Duration(seconds: 8), () async {
        try {
          await cache.learnAudioDetails(song);
          final inside = await cache.embeddedTags(song);
          if (inside != null) await enricher.useEmbedded(song, inside.tags, inside.cover);
        } catch (e) {
          logEvent('metadata', '${song.title}: couldn\'t use the file\'s own tags (${e.runtimeType})', level: LogLevel.warning);
        }
      });
    };
    _logStatusChanges();
    // Song info arrives from lookups here or another device; filing waits for it.
    scanner.progress.addListener(_toastChecking);
    enricher.run.addListener(() {
      if (enricher.run.value == EnrichRun.idle) {
        unawaited(learnLengths());
        filer.kick();
        unawaited(enricher.coverAll());
      }
    });
    uploader; // Subscribes to send updates.
    unawaited(tasks.start());
    await loadTaste();
    await loadMainChat();
    await uploader.loadSettings();
    unawaited(pool.load());
    // If the PC goes away, the phone takes over reading song lengths.
    // When a device joins or leaves, the shares change: pick up what is now this device's.
    link.devices.addListener(() {
      unawaited(db.pref('device_id').then((id) => _deviceId = id));
      unawaited(enricher.kick());
      unawaited(enricher.scanMoods());
      unawaited(learnLengths());
    });
    // Bots added on one device are added on the others.
    pool.onAdded = () => unawaited(link.sendBots());
    ui.onProfileChanged = () => unawaited(link.sendProfile());
    link.profile = ui.profileToWire;
    link.onRemoteProfile = ui.takeProfile;
    link.botTokens = pool.tokens;
    link.accountIn = () => userSession.loggedIn.value;
    link.onQrRequest = (peer, l) => qrRequests.value = (device: peer.name, link: l);
    userSession.loggedIn.addListener(link.sendAccount);
    link.onLogoutAll = () {
      if (userSession.loggedIn.value) unawaited(userSession.logOut());
    };
    link.onRemoteBots = pool.adopt;
    await spotify.load();
    await listenbrainz.load();
    sound.onNativePlayer = player.equalizer.attachMpv;
    await player.loadNormalization();
    await player.equalizer.load();
    await player.restoreSession();
    unawaited(listenbrainz.flush());
    player.countPlays = () => taste.value.learnFromPlays;
    enricher.moodLookupsAllowed = () => taste.value.lookups;
    enricher.owns = ownsSong;
    scanner.offloaded = () => !_isDesktop && pcConnected;
    enricher.gate = workGate;
    filer.deferToPc = () => !_isDesktop && pcConnected;
    await userSession.load();
    await loadRates(db);
    throttled(db.watchSongs(), const Duration(seconds: 2)).listen((songs) {
      liveSongs.value = {for (final s in songs) s.uniqueId: s};
    });
    throttled(db.watchStats(), const Duration(seconds: 2)).listen((s) => stats.value = s);
    throttled(db.watchMoodScanned(), const Duration(seconds: 2)).listen((n) => moodScanned.value = n);
    await deleteOldUserSession();

    final chats = await db.select(db.libraryChats).get();
    final token = await loadBotToken();
    if (token != null && chats.isNotEmpty) {
      td.botToken = token;
      await td.start();
      libraryReady.value = true;
      unawaited(_onStarted(chats));
    }
    // A saved device likely has this info already: let it merge first, so lookups only fill gaps.
    unawaited(() async {
      final saved = await db.pref('lan_addresses');
      if (saved != null && saved != '[]') await link.firstMerge(const Duration(seconds: 90));
      unawaited(enricher.kick());
      unawaited(enricher.scanMoods());
      unawaited(enricher.coverAll());
    }());
    unawaited(weather.load());
  }

  /// Feeds what the app already reports on screen into the log.
  void _logStatusChanges() {
    void follow<T>(String source, ValueNotifier<T> status, String Function(T) text, {LogLevel level = LogLevel.info}) {
      status.addListener(() {
        final line = text(status.value);
        if (line.isNotEmpty) logEvent(source, line, level: level);
      });
    }

    follow('scanner', scanner.progress, (v) => v ?? '');
    follow('metadata', enricher.run, (v) => 'Lookups: ${v.name}');
    follow('uploads', uploader.paused, (v) => v ? 'Paused' : 'Running');
    follow('sorting', mover.paused, (v) => v ? 'Paused' : 'Running');
    follow('sorting', mover.problem, (v) => v ?? '', level: LogLevel.error);
    follow('filing', filer.mover.problem, (v) => v ?? '', level: LogLevel.error);
    var filed = 0;
    follow('filing', filer.mover.jobs, (jobs) {
      final done = jobs.where((j) => j.status == MoveStatus.done).toList();
      if (done.length == filed) return '';
      filed = done.length;
      return done.isEmpty ? '' : '${done.last.song.title} → ${done.last.topicName}';
    });
    follow('playback', player.error, (v) => v ?? '', level: LogLevel.error);
    follow('login', botError, (v) => v ?? '', level: LogLevel.error);
    follow('login', td.authError, (v) => v ?? '', level: LogLevel.error);
    follow('sound', sound.current, (v) => 'Output: ${v?.name ?? 'none'}');
    follow('playback', player.current, (s) {
      final line = s == null ? 'Stopped' : '${s.title}: cover ${s.coverPath ?? 'none'}';
      if (line == _lastPlayingLine) return '';
      return _lastPlayingLine = line;
    });
  }

  String? _lastPlayingLine;

  Future<void> _onStarted(List<LibraryChat> chats) async {
    try {
      await td.ready();
    } catch (e) {
      botError.value = '$e';
      libraryReady.value = false;
      return;
    }
    for (final c in chats) {
      await _introduceChat(c.id);
    }
    final token = await loadBotToken();
    if (token != null) unawaited(link.start(token));
    await scanner.catchUp();
    // Once per install: reads topics and repeat posts, which older versions skipped.
    if (await db.pref('topics_read') == null) {
      await scanner.fullRescan();
      await db.setPref('topics_read', '1');
    }
    for (final c in chats) {
      await scanner.refreshTopicNames(c.id);
    }
    await cache.resumePins();
    filer.start();
  }

  Timer? _reconcileTimer;

  /// Songs arrive in bursts while scanning, so this waits for a pause.
  void _reconcileSoon() {
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(const Duration(seconds: 5), () => unawaited(reconcileImports(db)));
  }

  /// Another device added channels: this one reads them too.
  void _scanNewChats(List<LibraryChat> chats) {
    for (final c in chats) {
      _sync = _sync.then((_) async {
        await _introduceChat(c.id);
        await scanner.scanChat(c);
        await scanner.refreshTopicNames(c.id);
      }).then<void>((_) {}, onError: (_) {});
    }
  }

  /// How long a new device waits for another to hand over its library before
  /// reading every channel itself.
  static const _peerWait = Duration(seconds: 20);

  Future<void> _waitForPeerIfNew() async {
    final any = await (db.select(db.songs)..limit(1)).get();
    if (any.isEmpty) await link.firstMerge(_peerWait);
  }

  Future<void> _scanWhenReady(int chatId, {int endHint = 0}) async {
    await _waitForPeerIfNew();
    // Another device may have just said how far this chat has been read.
    final row = await (db.select(db.libraryChats)..where((c) => c.id.equals(chatId))).getSingle();
    await scanner.scanChat(row, endHint: endHint);
  }

  /// Signs the bot in if needed, checks each channel, and starts syncing it.
  /// Saves the token only once the login succeeds.
  Stream<BotCheck> addChannels(String token, List<ChannelRef> refs) async* {
    if (!_wired) await start();
    if (!td.started) {
      try {
        td.botToken = token;
        await td.start();
        await td.ready();
        await saveBotToken(token);
        botError.value = null;
        yield const BotCheck('Bot login', true, 'Logged in');
        // Channels from a restored backup need the bot introduced to them too.
        final existing = await db.select(db.libraryChats).get();
        if (existing.isNotEmpty) {
          unawaited(_onStarted(existing));
        } else {
          // A new device: another may be able to hand over the whole library.
          unawaited(link.start(token));
        }
      } catch (e) {
        await td.shutdown();
        await deleteBotData();
        yield BotCheck('Bot login', false, '$e');
        return;
      }
    }
    for (final ref in refs) {
      Json chat;
      try {
        chat = await _resolveChannel(ref);
      } catch (e) {
        yield BotCheck('Find channel', false, 'Can\'t see ${ref.username ?? ref.chatId}: $e');
        continue;
      }
      final id = chat['id'] as int;
      final name = chat['title'] as String? ?? '';
      final title = name.isEmpty ? '$id' : name;
      final group = supergroupIdOf(id);
      if (group == null) {
        yield BotCheck(title, false, 'Bots can only be used with channels and supergroups.');
        continue;
      }
      try {
        final info = await td.call({'@type': 'getSupergroup', 'supergroup_id': group});
        final status = (info['status'] as Json)['@type'];
        if (status != 'chatMemberStatusAdministrator' && status != 'chatMemberStatusCreator') {
          yield BotCheck(title, false, 'The bot is not an admin here. Add it as an admin first.');
          continue;
        }
      } on TdError catch (e) {
        yield BotCheck(title, false, '$e');
        continue;
      }
      await db.into(db.libraryChats).insertOnConflictUpdate(
            LibraryChatsCompanion.insert(id: Value(id), title: title),
          );
      await db.markChatAdded(id);
      // Syncs in the background, one channel at a time. The library opens now
      // and fills up as songs are found.
      final endHint = (ref.endMessage ?? 0) * messageIdStep;
      _sync = _sync
          .then((_) => _scanWhenReady(id, endHint: endHint))
          .then<void>((_) {}, onError: (_) {});
      yield BotCheck(title, true, 'Added. Songs appear as they sync.', added: true);
    }
  }

  Future<Json> _resolveChannel(ChannelRef ref) async {
    if (ref.username != null) {
      return td.call({'@type': 'searchPublicChat', 'username': ref.username});
    }
    if (supergroupIdOf(ref.chatId!) == null) {
      throw TdError(0, 'That isn\'t a channel or supergroup ID.');
    }
    await _introduceChat(ref.chatId!);
    return td.call({'@type': 'getChat', 'chat_id': ref.chatId});
  }

  /// Makes a channel known to the bot's TDLib database.
  Future<void> _introduceChat(int chatId) async {
    final group = supergroupIdOf(chatId);
    if (group == null) return;
    for (final force in [false, true]) {
      try {
        await td.call({'@type': 'createSupergroupChat', 'supergroup_id': group, 'force': force});
        break;
      } on TdError {
        // Offline, or the bot hasn't seen the channel; forcing needs no network.
      }
    }
    // A forced chat has no access hash, so reading its messages fails with
    // CHANNEL_INVALID until this fetches the channel. Retried on the next launch.
    try {
      await td
          .call({'@type': 'getSupergroup', 'supergroup_id': group})
          .timeout(const Duration(seconds: 10));
      // Now the channel's known, so is its name. Earlier it may have been saved as its id.
      final chat = await td.call({'@type': 'getChat', 'chat_id': chatId}).timeout(const Duration(seconds: 10));
      final title = chat['title'] as String? ?? '';
      if (title.isNotEmpty) {
        await (db.update(db.libraryChats)..where((c) => c.id.equals(chatId)))
            .write(LibraryChatsCompanion(title: Value(title)));
      }
    } on TdError {
      // Bot not in the channel.
    } on TimeoutException {
      // Offline.
    }
  }

  /// How a backup or restore is going, for the progress bar. Null when none is running.
  final backupProgress = ValueNotifier<({String stage, double? fraction})?>(null);

  void _backupStage(String stage, double? fraction) => backupProgress.value = (stage: stage, fraction: fraction);

  /// Writes a backup. With a [password], it also holds the API keys, the bot token, the
  /// other bots and the Spotify sign-in, encrypted with it.
  Future<File> saveBackup({String? password}) async {
    backupProgress.value = (stage: 'Starting', fraction: 0);
    try {
      final token = await loadBotToken();
      final id = td.apiId, hash = td.apiHash;
      String? sealed;
      if (password != null && token != null && id != null && hash != null) {
        _backupStage('Encrypting your keys', 0.01);
        final spotifyId = spotify.clientId.value, spotifyRefresh = await spotify.refreshToken();
        sealed = await sealCredentials(
          Credentials(
            apiId: id,
            apiHash: hash,
            botToken: token,
            extraBots: await pool.tokens(),
            spotifyClientId: spotifyRefresh == null ? null : spotifyId,
            spotifyRefreshToken: spotifyRefresh,
            listenBrainzToken: await listenbrainz.token(),
          ),
          password,
        );
      }
      String? sealedSession;
      if (password != null && userSession.loggedIn.value) {
        _backupStage('Saving your account session', 0.01);
        final session = await userSession.exportSession();
        if (session != null) sealedSession = await sealBytes(session, password);
      }
      return await createBackup(
        db,
        await getTemporaryDirectory(),
        sealedCredentials: sealed,
        sealedUserSession: sealedSession,
        onProgress: _backupStage,
      );
    } finally {
      backupProgress.value = null;
    }
  }

  /// Saves restored keys and token, and connects the bot if it isn't already.
  Future<void> applyCredentials(Credentials c) async {
    // The Spotify sign-in comes back as it was, without signing in again.
    if (c.spotifyClientId != null && c.spotifyRefreshToken != null) {
      await spotify.restore(c.spotifyClientId!, c.spotifyRefreshToken!);
    }
    if (c.listenBrainzToken != null) await listenbrainz.setToken(c.listenBrainzToken);
    await td.saveKeys(c.apiId, c.apiHash);
    await saveBotToken(c.botToken);
    botError.value = null;
    final chats = await db.select(db.libraryChats).get();
    if (!td.started || td.botToken != c.botToken) {
      await td.shutdown();
      await deleteBotData(); // A session for a different bot must not be reused.
      td.botToken = c.botToken;
      await td.start();
      unawaited(_onStarted(chats));
    }
    libraryReady.value = chats.isNotEmpty;
    // The other bots, once the main one is up.
    if (c.extraBots.isNotEmpty) unawaited(pool.adopt(c.extraBots));
  }

  /// Replaces the library with a backup. Throws [FormatException], leaving the
  /// library as it was, if the file isn't a usable backup.
  Future<({int songs, String? sealedCredentials, String? sealedUserSession, bool layoutApplied})> restoreFromBackup(String path, {bool applyLayout = false}) async {
    backupProgress.value = (stage: 'Starting', fraction: 0);
    try {
      return await _restoreFromBackup(path, applyLayout);
    } finally {
      backupProgress.value = null;
    }
  }

  Future<({int songs, String? sealedCredentials, String? sealedUserSession, bool layoutApplied})> _restoreFromBackup(String path, bool applyLayout) async {
    if (!_wired) await start();
    final dir = await getApplicationSupportDirectory();
    final result = await restoreBackup(
      db,
      path,
      Directory(p.join(dir.path, 'covers')),
      profileDir: Directory(p.join(dir.path, 'profile')),
      applyLayout: applyLayout,
      onProgress: _backupStage,
      beforeReplace: () async {
        await player.player.stop();
        player.queue.value = [];
        player.current.value = null;
        // Saved songs can't be tracked after this, so clear them while they still are.
        if (td.started) {
          for (final c in await db.select(db.libraryChats).get()) {
            await cache.removeChatFiles(c.id);
          }
        }
      },
    );
    enricher.resetCovers();
    await loadMainChat();
    // Theme, navigation bar and the rest, read again so the app looks as the backup says.
    if (result.layoutApplied) await ui.load();
    if (td.started) unawaited(_onStarted(await db.select(db.libraryChats).get()));
    unawaited(enricher.kick());
    return result;
  }

  /// Clears the bot and library from this device. API keys stay saved, and
  /// nothing in Telegram changes.
  Future<void> logOut() async {
    await link.stop();
    await player.player.stop();
    player.queue.value = [];
    player.current.value = null;
    libraryReady.value = false;
    filer.mover.cancel();
    mainChat.value = null;
    await td.shutdown();
    await db.wipe();
    await saveBotToken(null);
    await deleteBotData();
    enricher.resetCovers();
    final dir = await getApplicationSupportDirectory();
    final covers = Directory(p.join(dir.path, 'covers'));
    if (await covers.exists()) await covers.delete(recursive: true);
  }
}

final app = Services();
