import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../log.dart';
import 'td_client.dart';

/// One extra bot: its own Telegram session next to the main bot's.
class ExtraBot {
  ExtraBot(this.slot, this.client);
  final int slot;
  final TdClient client;

  /// `@name` once the bot has logged in.
  final username = ValueNotifier<String?>(null);

  /// Why it isn't working, if it isn't.
  final error = ValueNotifier<String?>(null);

  bool get ready => client.auth.value == 'authorizationStateReady';
}

/// The main bot plus any extra bots, so work can go to whichever is free. All of them
/// must be admins in the chat they work in: a post is the same post whichever bot reads
/// it, but each bot has its own file handles and its own downloaded copy.
class BotPool {
  BotPool(this.main);

  final TdClient main;
  final extras = ValueNotifier<List<ExtraBot>>([]);

  /// Told when a bot was added on this device, so other devices can add it too.
  void Function()? onAdded;
  final _updates = StreamController<(TdClient, Json)>.broadcast();

  /// Main first, then every extra that has logged in.
  List<TdClient> get ready => [
        if (main.auth.value == 'authorizationStateReady') main,
        for (final e in extras.value)
          if (e.ready) e.client,
      ];

  /// An update of [type] from any bot, with the bot it came from.
  Stream<(TdClient, Json)> updatesOf(String type) => _updates.stream.where((e) => e.$2['@type'] == type);

  Future<void> load() async {
    final tokens = await loadExtraBotTokens();
    for (final e in tokens.entries) {
      unawaited(_open(e.key, e.value));
    }
  }

  Future<ExtraBot> _open(int slot, String token) async {
    final client = TdClient(slot: slot)..botToken = token;
    await client.loadKeys();
    final bot = ExtraBot(slot, client);
    client.updates.listen((u) => _updates.add((client, u)));
    extras.value = [...extras.value, bot];
    client.authError.addListener(() => bot.error.value = client.authError.value);
    try {
      await client.start();
      await client.ready(timeout: const Duration(seconds: 45));
      final me = await client.call({'@type': 'getMe'});
      final names = (me['usernames'] as Map?)?['active_usernames'] as List?;
      bot.username.value = names == null || names.isEmpty ? null : '@${names.first}';
      logEvent('telegram', 'Extra bot ${bot.username.value ?? slot} is ready');
    } catch (e) {
      bot.error.value = '$e';
      logEvent('telegram', 'Extra bot $slot did not start: $e', level: LogLevel.warning);
    }
    return bot;
  }

  /// Adds a bot from its @BotFather token. Returns a problem in plain words, or null.
  Future<String?> add(String token) async {
    final t = parseBotToken(token);
    if (t == null) return "That doesn't look like a bot token.";
    if (extras.value.any((e) => e.client.botToken == t)) return 'That bot is already added.';
    final tokens = await loadExtraBotTokens();
    if (t == await loadBotToken() || tokens.containsValue(t)) return 'That bot is already added.';
    final slot = [0, ...tokens.keys].reduce((a, b) => a > b ? a : b) + 1;
    await saveExtraBotTokens({...tokens, slot: t});
    final bot = await _open(slot, t);
    if (bot.error.value != null && !bot.ready) {
      final why = bot.error.value;
      await remove(bot);
      return "That bot couldn't log in: $why";
    }
    onAdded?.call();
    return null;
  }

  /// The extra bots' tokens, to hand to another device of the same owner.
  Future<List<String>> tokens() async => (await loadExtraBotTokens()).values.toList();

  /// Adds bots another device has that this one lacks, and keeps them here. A bot that
  /// can't log in is left out.
  Future<void> adopt(List<String> remote) async {
    final have = (await loadExtraBotTokens()).values.toSet();
    final main = await loadBotToken();
    for (final t in remote) {
      if (parseBotToken(t) == null || t == main || have.contains(t) || extras.value.any((e) => e.client.botToken == t)) continue;
      logEvent('telegram', 'Adding a bot another device shares');
      await add(t);
    }
  }

  Future<void> remove(ExtraBot bot) async {
    await bot.client.shutdown();
    extras.value = extras.value.where((e) => e != bot).toList();
    final tokens = await loadExtraBotTokens()
      ..remove(bot.slot);
    await saveExtraBotTokens(tokens);
    final dir = await getApplicationSupportDirectory();
    for (final name in ['td_bot_${bot.slot}', 'td_files_bot_${bot.slot}']) {
      final d = Directory(p.join(dir.path, name));
      try {
        if (await d.exists()) await d.delete(recursive: true);
      } on FileSystemException {
        // Cleared with the app's data later.
      }
    }
  }
}
