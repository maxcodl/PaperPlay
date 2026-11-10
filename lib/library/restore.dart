import 'dart:math';

import '../telegram/td_client.dart';
import 'db.dart';

/// Old posts of songs copied to [mainChat] that Telegram no longer has, asked of Telegram
/// itself through the bot. Looks only at posts the library remembers outside the main chat.
/// [checked] says how many it asked about.
Future<({List<PostCopy> missing, int checked})> missingPosts(
  Future<Json> Function(Json) call,
  List<PostCopy> copies, {
  required int mainChat,
  Future<void> Function()? pause,
}) async {
  final byChat = <int, List<PostCopy>>{};
  for (final c in copies) {
    if (c.chatId != mainChat) (byChat[c.chatId] ??= []).add(c);
  }
  final missing = <PostCopy>[];
  var checked = 0;
  for (final e in byChat.entries) {
    for (var i = 0; i < e.value.length; i += _batch) {
      final chunk = e.value.sublist(i, min(i + _batch, e.value.length));
      final page = await call({
        '@type': 'getMessages',
        'chat_id': e.key,
        'message_ids': [for (final c in chunk) c.messageId],
      });
      final messages = page['messages'] as List;
      for (var j = 0; j < chunk.length; j++) {
        if (j >= messages.length || messages[j] == null) missing.add(chunk[j]);
      }
      checked += chunk.length;
      await pause?.call();
    }
  }
  return (missing: missing, checked: checked);
}

const _batch = 50;
