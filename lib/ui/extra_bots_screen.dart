import 'package:flutter/material.dart';

import '../app.dart';
import '../telegram/bot_pool.dart';

/// Extra bots that share the work with the main one: each does what it can in the chats
/// where it is an admin.
class ExtraBotsScreen extends StatelessWidget {
  const ExtraBotsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final field = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Add a bot'),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Bot token from @BotFather'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, field.text), child: const Text('Add')),
        ],
      ),
    );
    if (token == null || token.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Logging the bot in...'), duration: Duration(seconds: 30)));
    final problem = await app.pool.add(token);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(problem ?? 'Bot added. Make it an admin of your main chat so it can work there.'),
    ));
  }

  Future<void> _remove(BuildContext context, ExtraBot bot) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove ${bot.username.value ?? 'this bot'}?'),
        content: const Text('It stops sharing the work, and its downloaded files on this device are deleted. Nothing in Telegram changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true) await app.pool.remove(bot);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Extra bots')),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a bot'),
          onPressed: () => _add(context),
        ),
        body: ValueListenableBuilder(
          valueListenable: app.pool.extras,
          builder: (context, bots, _) => ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'More bots share the uploading. Create each one in @BotFather and add it as an admin '
                  'of your main chat, with the right to post and delete messages. A bot only works in '
                  'chats where it is an admin; anything it can\'t reach is left to the main bot, '
                  'or to your own account.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy_rounded),
                title: const Text('Main bot'),
                subtitle: ValueListenableBuilder(
                  valueListenable: app.td.auth,
                  builder: (_, auth, _) => Text(auth == 'authorizationStateReady' ? 'Working' : 'Not connected'),
                ),
              ),
              for (final bot in bots)
                ListenableBuilder(
                  listenable: Listenable.merge([bot.username, bot.error, bot.client.auth]),
                  builder: (context, _) => ListTile(
                    leading: const Icon(Icons.smart_toy_outlined),
                    title: Text(bot.username.value ?? 'Bot ${bot.slot}'),
                    subtitle: Text(bot.ready ? 'Working' : (bot.error.value ?? 'Logging in...')),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _remove(context, bot),
                    ),
                  ),
                ),
              if (bots.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No extra bots yet.'),
                ),
            ],
          ),
        ),
      );
}
