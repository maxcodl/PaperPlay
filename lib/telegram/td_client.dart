import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:handy_tdlib_next/handy_tdlib_next.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../log.dart';
import 'td_compat.dart';

typedef Json = Map<String, dynamic>;

const _storage = FlutterSecureStorage();
const _apiIdKey = 'tg_api_id', _apiHashKey = 'tg_api_hash';

/// Validates keys as typed by the user; null when malformed.
({int id, String hash})? parseApiKeys(String id, String hash) {
  final parsedId = int.tryParse(id.trim());
  final trimmedHash = hash.trim();
  if (parsedId == null || parsedId <= 0) return null;
  if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(trimmedHash)) return null;
  return (id: parsedId, hash: trimmedHash);
}

const _botTokenKey = 'tg_bot_token';

class ChannelRef {
  const ChannelRef({this.chatId, this.username, this.endMessage});
  final int? chatId;
  final String? username;

  /// Server id of a message in the channel, when a post link gave one.
  final int? endMessage;
}

/// Reads a channel id, @username or post link, as typed; null when unreadable.
ChannelRef? parseChannelRef(String input) {
  const prefix = -1000000000000;
  final t = input.trim();
  if (RegExp(r'^-100\d+$').hasMatch(t)) return ChannelRef(chatId: int.parse(t));
  if (RegExp(r'^\d+$').hasMatch(t)) {
    return ChannelRef(chatId: prefix - int.parse(t));
  }
  final private = RegExp(
    r't\.me/c/(\d+)(?:/\d+)*?(?:/(\d+))?/?$',
  ).firstMatch(t);
  if (private != null) {
    return ChannelRef(
      chatId: prefix - int.parse(private[1]!),
      endMessage: int.tryParse(private[2] ?? ''),
    );
  }
  final public = RegExp(
    r'(?:t\.me/|^@)([A-Za-z]\w{3,})(?:/(\d+))?/?$',
  ).firstMatch(t);
  if (public != null) {
    return ChannelRef(
      username: public[1],
      endMessage: int.tryParse(public[2] ?? ''),
    );
  }
  return null;
}

/// Validates a @BotFather token as pasted; null when malformed.
String? parseBotToken(String token) {
  final t = token.trim();
  return RegExp(r'^\d+:[A-Za-z0-9_-]{30,}$').hasMatch(t) ? t : null;
}

Future<String?> loadBotToken() => _storage.read(key: _botTokenKey);

Future<void> saveBotToken(String? token) =>
    _storage.write(key: _botTokenKey, value: token);

const _extraBotsKey = 'tg_extra_bots';

/// Tokens of the extra bots, by slot. Kept in the OS keystore, like the main token.
Future<Map<int, String>> loadExtraBotTokens() async {
  final raw = await _storage.read(key: _extraBotsKey);
  if (raw == null) return {};
  return {for (final e in (jsonDecode(raw) as Map).entries) int.parse(e.key as String): e.value as String};
}

Future<void> saveExtraBotTokens(Map<int, String> tokens) => _storage.write(
      key: _extraBotsKey,
      value: jsonEncode({for (final e in tokens.entries) '${e.key}': e.value}),
    );

/// Requests that can reach Telegram's servers, for the activity display.
/// Local lookups such as getMessage on stored messages aren't counted.
const _safeFields = {
  'chat_id',
  'message_id',
  'message_ids',
  'file_id',
  'offset',
  'limit',
  'supergroup_id',
  'message_thread_id',
  'forum_topic_id',
};

/// A request for the log: its type and plain ids only. Bodies are never logged,
/// since some carry the bot token, API hash or database key.
String describeRequest(Json request) {
  final fields = [
    for (final key in _safeFields)
      if (request[key] != null) '$key=${request[key]}',
  ];
  return [request['@type'] ?? '?', ...fields].join(' ');
}

/// An update for the log, in the same spirit as [describeRequest].
String describeUpdate(Json u) {
  final message = u['message'];
  final chat = u['chat_id'] ?? (message is Map ? message['chat_id'] : null);
  final id = message is Map ? message['id'] : null;
  return [
    u['@type'],
    if (chat != null) 'chat_id=$chat',
    if (id != null) 'message_id=$id',
    if (u['message_ids'] != null) 'message_ids=${u['message_ids']}',
    if (u['old_message_id'] != null) 'old_message_id=${u['old_message_id']}',
    if (u['authorization_state'] is Map) (u['authorization_state'] as Map)['@type'],
    if (u['error'] is Map) 'error=${(u['error'] as Map)['message']}',
  ].join(' ');
}

class TdActivity extends ChangeNotifier {
  var reads = 0, downloads = 0, uploads = 0, rateLimits = 0;

  void record(String? type) {
    switch (type) {
      case 'getMessages':
        reads++;
      case 'downloadFile':
        downloads++;
      case 'sendMessage':
        uploads++;
      default:
        return;
    }
    notifyListeners();
  }

  void recordRateLimit() {
    rateLimits++;
    notifyListeners();
  }
}

class TdError implements Exception {
  TdError(this.code, this.message);
  final int code;
  final String message;

  /// Seconds to wait, when this is a flood-control error.
  int? get retryAfter => code == 429
      ? int.tryParse(
              RegExp(r'retry after (\d+)').firstMatch(message)?[1] ?? '',
            ) ??
            5
      : null;

  @override
  String toString() => message;
}

/// Updates the app reacts to. Everything else is dropped off the UI isolate.
const _wanted = {
  'updateAuthorizationState',
  'updateFile',
  'updateNewMessage',
  'updateDeleteMessages',
  'updateMessageSendSucceeded',
  'updateMessageSendFailed',
  'updateForumTopicInfo',
};

/// Windows ships tdjson.dll beside the exe, Linux libtdjson.so in its lib folder; Android uses
/// the plugin's .so.
final String? _tdLib = Platform.isWindows
    ? p.join(p.dirname(Platform.resolvedExecutable), 'tdjson.dll')
    : Platform.isLinux
        ? p.join(p.dirname(Platform.resolvedExecutable), 'lib', 'libtdjson.so')
        : null;

/// TDLib aborts the whole app if `td_receive` is ever called from two threads at once. The
/// app outlives its window on Android, so reopening it can start a new Dart engine while
/// the old engine's receive loop is still going. Which loop may run is therefore kept in an
/// environment variable: those belong to the process, whatever engine or isolate reads them.
const _loopVar = 'TELEPLAYER_TD_LOOP';

String? _loopToken() {
  if (!Platform.isAndroid) return null;
  final name = _loopVar.toNativeUtf8();
  try {
    final found = ffi.DynamicLibrary.process()
        .lookupFunction<ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>), ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>)>('getenv')(name);
    return found.address == 0 ? null : found.toDartString();
  } finally {
    malloc.free(name);
  }
}

void _setLoopToken(String value) {
  if (!Platform.isAndroid) return;
  final name = _loopVar.toNativeUtf8(), text = value.toNativeUtf8();
  try {
    ffi.DynamicLibrary.process()
        .lookupFunction<ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32), int Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int)>(
            'setenv')(name, text, 1);
  } finally {
    malloc.free(name);
    malloc.free(text);
  }
}

Future<void> _receiveLoop((SendPort, String) args) async {
  final (out, token) = args;
  await TdPlugin.initialize(_tdLib);
  // Stops by itself as soon as a newer loop has taken over.
  while (_loopToken() == token || !Platform.isAndroid) {
    final raw = TdPlugin.instance.tdReceive(1);
    if (raw == null) continue;
    final Json obj = jsonDecode(raw);
    if (obj.containsKey('@extra') || _wanted.contains(obj['@type'])) {
      out.send(obj);
    }
  }
}

/// Request/response and update stream over libtdjson, logged in as a bot, or with
/// [user] as the owner's own account, used only as an optional fallback for deletes
/// the bot isn't allowed. Never logs request contents: they include the bot token.
class TdClient {
  TdClient({this.user = false, this.slot = 0});

  final bool user;

  /// 0 is the main bot; 1 and up are extra bots, each with its own session folder.
  final int slot;
  final activity = TdActivity();

  /// The bot to log in as. Set before [start].
  String? botToken;

  // One receive loop serves every client: td_receive is global, so two loops would
  // split each other's answers.
  static Future<void>? _runtime;
  static final _clients = <int, TdClient>{};

  static Future<void> _startRuntime() async {
    await TdPlugin.initialize(_tdLib);
    TdPlugin.instance.tdExecute(
      jsonEncode({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 1}),
    );
    final port = ReceivePort()
      ..listen((m) {
        final j = m as Json;
        _clients[j['@client_id']]?._onMessage(j);
      });
    // An older engine's loop notices the new token within a second of its next receive, so
    // wait that out before starting this one: two at once would abort the app.
    final previous = _loopToken();
    final token = '$pid-${DateTime.now().microsecondsSinceEpoch}';
    _setLoopToken(token);
    if (previous != null) await Future<void>.delayed(const Duration(milliseconds: 2500));
    await Isolate.spawn(_receiveLoop, (port.sendPort, token));
  }

  var _closed = Completer<void>();
  var _stopping = false;

  bool get started => _started;

  /// Current `authorizationState*` type; empty until TDLib reports one.
  final auth = ValueNotifier<String>('');
  final _updates = StreamController<Json>.broadcast();
  final _pending = <int, Completer<Json>>{};
  final _sent = <int, String>{};
  var _nextExtra = 1;
  late int _clientId;

  Stream<Json> get updates => _updates.stream;

  Stream<Json> updatesOf(String type) =>
      updates.where((u) => u['@type'] == type);

  /// Whether API keys are saved.
  final hasKeys = ValueNotifier(false);
  int? _apiId;
  String? _apiHash;
  int? get apiId => _apiId;
  String? get apiHash => _apiHash;
  var _started = false;

  Future<void> loadKeys() async {
    _apiId = int.tryParse(await _storage.read(key: _apiIdKey) ?? '');
    _apiHash = await _storage.read(key: _apiHashKey);
    hasKeys.value = _apiId != null && _apiHash != null;
  }

  Future<void> saveKeys(int id, String hash) async {
    await _storage.write(key: _apiIdKey, value: '$id');
    await _storage.write(key: _apiHashKey, value: hash);
    _apiId = id;
    _apiHash = hash;
    hasKeys.value = true;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    authError.value = null;
    _closed = Completer<void>();
    await (_runtime ??= _startRuntime());
    _openClient();
  }

  /// Waits for login to finish; throws with the reason if it fails.
  Future<void> ready({Duration timeout = const Duration(seconds: 30)}) async {
    final done = Completer<void>();
    void check() {
      if (done.isCompleted) return;
      if (auth.value == 'authorizationStateReady') done.complete();
      if (authError.value != null) {
        done.completeError(TdError(0, authError.value!));
      }
    }

    auth.addListener(check);
    authError.addListener(check);
    check();
    try {
      await done.future.timeout(timeout);
    } finally {
      auth.removeListener(check);
      authError.removeListener(check);
    }
  }

  /// Disconnects from Telegram until [start] is called again. The session
  /// stays on disk, so no new login is needed.
  Future<void> shutdown() async {
    if (!_started) return;
    _stopping = true;
    try {
      await call({'@type': 'close'}).timeout(const Duration(seconds: 10));
      await _closed.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      // Already closed, or never got as far as starting.
    }
  }

  void _openClient() {
    _clientId = TdPlugin.instance.tdCreateClientId();
    _clients[_clientId] = this;
    // TDLib only starts emitting updates after the first request.
    call({'@type': 'getOption', 'name': 'version'}).then(
      (v) => setTdVersion(v['value'] as String?),
      onError: (Object _) {},
    );
  }

  void _onMessage(Json m) {
    final extra = m['@extra'];
    if (extra != null) {
      final c = _pending.remove(extra);
      final what = _sent.remove(extra);
      if (c == null) return;
      if (m['@type'] == 'error' && m['code'] == 429) activity.recordRateLimit();
      if (m['@type'] == 'error') {
        logEvent(
          'telegram',
          '$what failed: ${m['code']} ${m['message']}',
          level: m['code'] == 429 ? LogLevel.warning : LogLevel.error,
        );
        c.completeError(TdError(m['code'] as int, m['message'] as String));
      } else {
        c.complete(m);
      }
      return;
    }
    // Sent many times a second during a download. The owner's own chats aren't logged.
    if (m['@type'] != 'updateFile' && !user) logEvent('telegram', describeUpdate(m));
    if (m['@type'] == 'updateAuthorizationState') {
      final st = m['authorization_state'] as Json;
      if (st['@type'] == 'authorizationStateWaitOtherDeviceConfirmation') qrLink.value = st['link'] as String?;
      _onAuth(st['@type'] as String);
    }
    _updates.add(m);
  }

  void _onAuth(String state) {
    auth.value = state;
    if (state == 'authorizationStateWaitTdlibParameters') {
      _sendParameters().catchError((Object e) => authError.value = '$e');
    } else if (state == 'authorizationStateWaitPhoneNumber') {
      // TDLib's name for "not logged in". The bot logs in by itself; the owner's
      // account waits for the phone number from the login screen.
      if (!user) _logIn();
    } else if (state == 'authorizationStateClosed') {
      if (!_stopping && !user) authError.value = 'Telegram ended the bot session.';
      _stopping = false;
      _started = false;
      if (!_closed.isCompleted) _closed.complete();
    }
  }

  Future<void> _logIn() async {
    authError.value = null;
    try {
      await call({'@type': 'checkAuthenticationBotToken', 'token': botToken});
    } on TdError catch (e) {
      authError.value = e.message;
    }
  }

  /// The `tg://login` link another logged-in device approves, while waiting for that.
  final qrLink = ValueNotifier<String?>(null);

  /// Last failure from setup or login.
  final authError = ValueNotifier<String?>(null);

  Future<void> _sendParameters() async {
    final dir = await getApplicationSupportDirectory();
    final suffix = slot == 0 ? '' : '_$slot';
    await call({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': p.join(dir.path, user ? 'td_user' : 'td_bot$suffix'),
      'files_directory': p.join(dir.path, user ? 'td_files_user' : 'td_files_bot$suffix'),
      'database_encryption_key': keyOverride ?? await _encryptionKey(),
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': !user,
      'use_secret_chats': false,
      'api_id': _apiId,
      'api_hash': _apiHash,
      'system_language_code': Platform.localeName.split('_').first,
      'device_model': Platform.operatingSystem,
      'system_version': Platform.operatingSystemVersion,
      'application_version': '0.1.0',
    });
  }

  /// Opens the database with this key instead of the device's own, for one restored from a
  /// backup. The session is then re-keyed to the device's own and this is cleared.
  String? keyOverride;

  /// The key this device encrypts its TDLib databases with.
  Future<String> databaseKey() => _encryptionKey();

  /// The TDLib database holds the bot session, so it is encrypted with a random
  /// key kept in the OS keystore.
  Future<String> _encryptionKey() async {
    const name = 'td_db_key';
    final existing = await _storage.read(key: name);
    if (existing != null) return existing;
    final rnd = Random.secure();
    final key = base64Encode(List.generate(32, (_) => rnd.nextInt(256)));
    await _storage.write(key: name, value: key);
    return key;
  }

  Future<Json> call(Json request) {
    activity.record(request['@type'] as String?);
    final extra = _nextExtra++;
    final c = _pending[extra] = Completer<Json>();
    final what = describeRequest(request);
    _sent[extra] = what;
    // Streaming asks this hundreds of times a second; logging it buries everything else.
    if (request['@type'] != 'getFileDownloadedPrefixSize') logEvent('telegram', what);
    TdPlugin.instance.tdSend(
      _clientId,
      jsonEncode({...request, '@extra': extra}),
    );
    return c.future;
  }

  Future<String> version() async =>
      (await call({'@type': 'getOption', 'name': 'version'}))['value']
          as String? ??
      '?';
}
