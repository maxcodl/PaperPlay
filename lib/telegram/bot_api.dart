import 'dart:convert';

import 'package:http/http.dart' as http;

/// Telegram's HTTP Bot API, used only to ask the server what TDLib can't decide for itself.
/// TDLib works from information it has cached, which can be out of date: it kept refusing
/// to delete posts the bot had been given the right to delete. The server decides for real.
///
/// The bot token is part of every address here, so nothing from a failed request is ever
/// reported: its text can contain the address.
class BotApi {
  BotApi(this._token, {http.Client? client}) : _http = client ?? http.Client();

  final Future<String?> Function() _token;
  final http.Client _http;
  int? _botId;

  Future<Map<String, dynamic>?> _call(String method, Map<String, Object> params) async {
    final token = await _token();
    if (token == null) return null;
    try {
      final res = await _http
          .post(Uri.https('api.telegram.org', '/bot$token/$method'), body: {for (final e in params.entries) e.key: '${e.value}'})
          .timeout(const Duration(seconds: 15));
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on Exception {
      return null;
    }
  }

  /// Whether the bot may delete other people's posts in [chatId], as Telegram says it.
  /// Null if Telegram couldn't be asked.
  Future<bool?> canDelete(int chatId) async {
    _botId ??= ((await _call('getMe', {}))?['result'] as Map?)?['id'] as int?;
    final id = _botId;
    if (id == null) return null;
    final member = (await _call('getChatMember', {'chat_id': chatId, 'user_id': id}))?['result'] as Map?;
    if (member == null) return null;
    return member['status'] == 'creator' || (member['status'] == 'administrator' && member['can_delete_messages'] == true);
  }

  /// Deletes up to 100 posts in one call. Telegram skips the ones it can't delete and still
  /// answers ok, so the caller checks which are left. False if Telegram couldn't be asked.
  Future<bool> deleteMessages(int chatId, List<int> tdlibMessageIds) async {
    final reply = await _call('deleteMessages', {'chat_id': chatId, 'message_ids': jsonEncode([for (final m in tdlibMessageIds) m >> 20])});
    return reply?['ok'] == true;
  }

  /// Deletes a post through the server. Null on success, otherwise Telegram's own reason.
  /// [tdlibMessageId] is TDLib's id, which is the server's shifted up by 20 bits.
  Future<String?> deleteMessage(int chatId, int tdlibMessageId) async {
    final reply = await _call('deleteMessage', {'chat_id': chatId, 'message_id': tdlibMessageId >> 20});
    if (reply == null) return 'Telegram couldn\'t be reached';
    return reply['ok'] == true ? null : '${reply['description'] ?? 'refused'}';
  }
}
