import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../library/db.dart';
import '../log.dart';
import '../pace.dart';
import 'td_client.dart';

/// The owner's own Telegram account, optional and off by default. Used only to
/// delete posts the bot is refused (Telegram stops bots deleting posts older than
/// 48 hours). It reads and posts nothing, and only connects when a delete needs it.
/// A song post in one of the account's chats.
typedef ChatPost = ({
  int id,
  String uniqueId,
  String title,
  String artist,
  int duration,
  int size,
  String mime,
  String fileName,
});

class UserSession {
  UserSession(this._db);

  final AppDb _db;
  final td = TdClient(user: true);
  static const _key = 'user_session';

  /// Logged in on this device. Per device: a session can't be copied to another.
  final loggedIn = ValueNotifier(false);

  Future<void> load() async => loggedIn.value = await _db.pref(_key) == '1';

  /// Starts the login; the screen follows [TdClient.auth] for the next step.
  Future<void> begin() async {
    await td.loadKeys();
    await td.start();
  }

  /// Asks for a login link another of the owner's logged-in devices can approve, so this
  /// device gets its own session without a code. [td.qrLink] holds the link once ready.
  Future<void> beginQr() async {
    await begin();
    for (var i = 0; i < 40 && td.auth.value != 'authorizationStateWaitPhoneNumber'; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // Logged in once the other device approves, even if this screen was left meanwhile.
    void ready() {
      if (td.auth.value == 'authorizationStateReady') {
        td.auth.removeListener(ready);
        unawaited(finished());
      }
    }

    td.auth.addListener(ready);
    await td.call({'@type': 'requestQrCodeAuthentication', 'other_user_ids': <int>[]});
  }

  /// Approves another device's login link with this device's session.
  Future<void> approveQr(String link) async {
    await _ready();
    await td.call({'@type': 'confirmQrCodeAuthentication', 'link': link});
  }

  /// The account's session as bytes for a backup: its TDLib database and the key that opens
  /// it. Closes the session first, so the files are whole; it opens again when next needed.
  /// Null if there is no session on disk.
  Future<Uint8List?> exportSession() async {
    if (!loggedIn.value) return null;
    if (td.started) await td.shutdown();
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'td_user'));
    if (!await dir.exists()) return null;
    final archive = Archive();
    var size = 0;
    await for (final f in dir.list(recursive: true)) {
      if (f is! File) continue;
      final bytes = await f.readAsBytes();
      size += bytes.length;
      archive.addFile(ArchiveFile(p.relative(f.path, from: dir.path).replaceAll('\\', '/'), bytes.length, bytes));
    }
    // A runaway folder would make a huge backup; the account can sign in again instead.
    if (size > 300 * 1024 * 1024) return null;
    final key = utf8.encode(await td.databaseKey());
    archive.addFile(ArchiveFile('__key', key.length, key));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Puts a backed-up session back and re-keys it to this device's own key. If Telegram
  /// has ended the session since (it can't be used on two devices at once), the account is
  /// simply logged out here and can sign in again.
  Future<bool> importSession(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final keyFile = archive.findFile('__key');
    if (keyFile == null) return false;
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'td_user'));
    if (td.started) await td.shutdown();
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (final f in archive) {
      if (!f.isFile || f.name == '__key' || f.name.contains('..')) continue;
      final out = File(p.join(dir.path, f.name));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.content as List<int>);
    }
    td.keyOverride = utf8.decode(keyFile.content as List<int>);
    try {
      await begin();
      await td.ready(timeout: const Duration(seconds: 30));
      await td.call({'@type': 'setDatabaseEncryptionKey', 'new_encryption_key': await td.databaseKey()});
      await finished();
      return true;
    } catch (e) {
      logEvent('filing', 'The backed-up account session could not be used: ${e is TdError ? e.message : e.runtimeType}',
          level: LogLevel.warning);
      await logOut();
      return false;
    } finally {
      td.keyOverride = null;
    }
  }

  Future<void> phone(String number) =>
      td.call({'@type': 'setAuthenticationPhoneNumber', 'phone_number': number});

  Future<void> code(String code) => td.call({'@type': 'checkAuthenticationCode', 'code': code});

  Future<void> password(String password) =>
      td.call({'@type': 'checkAuthenticationPassword', 'password': password});

  Future<void> finished() async {
    await _db.setPref(_key, '1');
    loggedIn.value = true;
  }

  Future<void> logOut() async {
    try {
      if (!td.started) await begin();
      await td.call({'@type': 'logOut'}).timeout(const Duration(seconds: 15));
    } catch (_) {
      // The session is forgotten here either way.
    }
    await _db.setPref(_key, '0');
    loggedIn.value = false;
  }

  Future<void> _ready() async {
    if (!td.started) await begin();
    await td.ready(timeout: const Duration(seconds: 20));
  }

  /// The groups and channels this account is in, newest activity first.
  Future<List<({int id, String title, bool channel})>> groupsAndChannels() async {
    await _ready();
    try {
      await td.call({'@type': 'loadChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': 500});
    } on TdError {
      // Already all loaded.
    }
    final ids = ((await td.call({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 500,
    }))['chat_ids'] as List)
        .cast<int>();
    final out = <({int id, String title, bool channel})>[];
    for (final id in ids) {
      final chat = await td.call({'@type': 'getChat', 'chat_id': id});
      final type = chat['type'] as Map;
      if (type['@type'] == 'chatTypePrivate' || type['@type'] == 'chatTypeSecret') continue;
      out.add((id: id, title: chat['title'] as String, channel: type['is_channel'] == true));
    }
    return out;
  }

  /// Every song post in [chatId], oldest first: audio, and documents that are audio.
  Future<List<ChatPost>> songsIn(int chatId, {void Function(int found)? onProgress}) async {
    await _ready();
    final found = <int, ChatPost>{};
    for (final filter in ['searchMessagesFilterAudio', 'searchMessagesFilterDocument']) {
      var from = 0;
      while (true) {
        final page = await td.call({
          '@type': 'searchChatMessages',
          'chat_id': chatId,
          'query': '',
          'from_message_id': from,
          'offset': 0,
          'limit': 100,
          'filter': {'@type': filter},
        });
        final messages = (page['messages'] as List).cast<Map<String, dynamic>>();
        for (final m in messages) {
          final c = m['content'] as Map;
          if (c['@type'] == 'messageAudio') {
            final a = c['audio'] as Map;
            found[m['id'] as int] = (
              id: m['id'] as int,
              uniqueId: ((a['audio'] as Map)['remote'] as Map)['unique_id'] as String,
              title: a['title'] as String? ?? a['file_name'] as String? ?? '',
              artist: a['performer'] as String? ?? '',
              duration: a['duration'] as int? ?? 0,
              size: (a['audio'] as Map)['size'] as int? ?? 0,
              mime: a['mime_type'] as String? ?? '',
              fileName: a['file_name'] as String? ?? '',
            );
          } else if (c['@type'] == 'messageDocument') {
            final d = c['document'] as Map;
            if (!(d['mime_type'] as String? ?? '').startsWith('audio/')) continue;
            found[m['id'] as int] = (
              id: m['id'] as int,
              uniqueId: ((d['document'] as Map)['remote'] as Map)['unique_id'] as String,
              title: d['file_name'] as String? ?? '',
              artist: '',
              duration: 0,
              size: (d['document'] as Map)['size'] as int? ?? 0,
              mime: d['mime_type'] as String? ?? '',
              fileName: d['file_name'] as String? ?? '',
            );
          }
        }
        onProgress?.call(found.length);
        final next = page['next_from_message_id'] as int? ?? 0;
        if (messages.isEmpty || next == 0) break;
        from = next;
        // Paced like the bot's channel reading (Settings, Library, Speed).
        await Future<void>.delayed(gap(Work.reading));
      }
    }
    return found.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Copies one post into [toChat]'s General as this account, without a "forwarded" label.
  Future<void> copyPost(int fromChat, int messageId, int toChat) async {
    await _ready();
    try {
      await td.call({'@type': 'getChat', 'chat_id': toChat});
    } on TdError {
      await td.call({'@type': 'createSupergroupChat', 'supergroup_id': -toChat - 1000000000000, 'force': false});
    }
    await td.call({
      '@type': 'forwardMessages',
      'chat_id': toChat,
      'from_chat_id': fromChat,
      'message_ids': [messageId],
      'send_copy': true,
      'remove_caption': false,
    });
  }

  /// Deletes one post for everyone. False if not logged in or Telegram refuses.
  Future<bool> delete(int chatId, int messageId) => deleteMany(chatId, [messageId]);

  /// Deletes posts for everyone, up to 100 to a call. Returns the ids Telegram still refused
  /// to remove (all of them if this account isn't logged in).
  Future<List<int>> deleteBatch(int chatId, List<int> ids) async {
    final left = <int>[];
    for (var i = 0; i < ids.length; i += 100) {
      final part = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      if (!await deleteMany(chatId, part)) {
        // One refused post fails the whole call, so the rest go singly.
        if (part.length == 1) {
          left.addAll(part);
        } else {
          for (final id in part) {
            if (!await deleteMany(chatId, [id])) left.add(id);
          }
        }
      }
    }
    return left;
  }

  Future<bool> deleteMany(int chatId, List<int> messageIds) async {
    if (!loggedIn.value) return false;
    try {
      if (!td.started) await begin();
      await td.ready(timeout: const Duration(seconds: 20));
      try {
        await td.call({'@type': 'getChat', 'chat_id': chatId});
      } on TdError {
        // Not in this session's cache yet. A supergroup's chat id is -100 followed by
        // its supergroup id; asking for the supergroup makes the chat known.
        // A new session knows no chats yet: loading the chat list fills them in.
        try {
          await td.call({'@type': 'loadChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': 500});
        } on TdError {
          // Already all loaded.
        }
        // -100… is a supergroup or channel; any other negative id is a basic group.
        if (chatId <= -1000000000000) {
          await td.call({'@type': 'createSupergroupChat', 'supergroup_id': -chatId - 1000000000000, 'force': false});
        } else {
          await td.call({'@type': 'createBasicGroupChat', 'basic_group_id': -chatId, 'force': false});
        }
      }
      await td.call({'@type': 'deleteMessages', 'chat_id': chatId, 'message_ids': messageIds, 'revoke': true});
      return true;
    } catch (e) {
      logEvent('filing', 'Your account couldn\'t delete it either: ${e is TdError ? e.message : e.runtimeType}',
          level: LogLevel.warning);
      return false;
    }
  }
}
