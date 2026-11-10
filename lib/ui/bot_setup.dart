import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import 'widgets.dart';
import '../telegram/channels.dart';
import '../telegram/td_client.dart';

/// First-run setup: API keys, bot token and channels. Also adds more channels
/// later, when opened from Settings.
class BotSetupScreen extends StatefulWidget {
  const BotSetupScreen({super.key});

  @override
  State<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends State<BotSetupScreen> {
  final _apiId = TextEditingController();
  final _apiHash = TextEditingController();
  final _token = TextEditingController();
  final _channels = TextEditingController();
  final _results = <BotCheck>[];
  var _running = false;
  String? _error;

  /// A backup brought its channels with it, so none need typing.
  var _restored = false;

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;
    setState(() {
      _error = null;
      _running = true;
      _results.clear();
    });
    try {
      final result = await app.restoreFromBackup(path);
      _restored = true;
      _results.add(BotCheck('Backup restored', true, '${result.songs} songs. Enter your bot details to finish.'));
      if (mounted && await applyBackupCredentials(context, result.sealedCredentials)) {
        return; // The library opens by itself now.
      }
    } on FormatException catch (e) {
      _results.add(BotCheck('Backup not restored', false, e.message));
    }
    if (mounted) setState(() => _running = false);
  }

  bool get _hasKeys => app.td.hasKeys.value;
  bool get _hasBot => app.td.started;
  bool get _anyAdded => _results.any((r) => r.added);

  @override
  void dispose() {
    _apiId.dispose();
    _apiHash.dispose();
    _token.dispose();
    _channels.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // Blank fields keep saved keys. Filled ones replace them, so a typo is fixable.
    final blank = _apiId.text.trim().isEmpty && _apiHash.text.trim().isEmpty;
    final keys = _hasKeys && blank ? null : parseApiKeys(_apiId.text, _apiHash.text);
    if (keys == null && !(_hasKeys && blank) && !_hasBot) {
      return setState(() => _error = 'Check api_id and api_hash.');
    }
    final token = _hasBot ? '' : parseBotToken(_token.text);
    if (token == null) {
      return setState(() => _error = 'That doesn\'t look like a bot token.');
    }
    final lines = _channels.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final refs = lines.map(parseChannelRef).toList();
    // With none, another device on this network can provide them. Only for a new setup:
    // from Settings it just means nothing was typed.
    if (refs.isEmpty && !_restored && app.libraryReady.value) {
      return setState(() => _error = 'Add at least one channel.');
    }
    final bad = refs.indexOf(null);
    if (bad >= 0) return setState(() => _error = 'Can\'t read this line: ${lines[bad].trim()}');

    setState(() {
      _error = null;
      _running = true;
      _results.clear();
    });
    if (keys != null) await app.td.saveKeys(keys.id, keys.hash);
    await for (final result in app.addChannels(token, refs.cast<ChannelRef>())) {
      if (mounted) setState(() => _results.add(result));
    }
    if (!mounted) return;
    setState(() => _running = false);
    // Everything worked, so go to the library and let it fill up there.
    if (_results.isNotEmpty && _results.every((r) => r.ok)) _openLibrary();
  }

  void _openLibrary() {
    if (app.libraryReady.value) {
      Navigator.pop(context);
    } else {
      app.libraryReady.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text(app.libraryReady.value ? 'Add channels' : 'Paper Play')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!app.libraryReady.value) ...[
              const InfoText(
                "Unofficial player that streams music from your Telegram channels through a bot.",
              ),
              gap,
              OutlinedButton.icon(
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restore a backup'),
                onPressed: _running ? null : _restore,
              ),
              gap,
            ],
            ValueListenableBuilder(
              valueListenable: app.botError,
              builder: (context, error, _) => error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'The bot couldn\'t log in: $error',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
            ),
            if (!_hasBot) ...[
              Text('1. API keys', style: text.titleSmall),
              Text(
                _hasKeys
                    ? 'Saved. Leave these blank to keep them, or fill them in to replace them.'
                    : 'Log in at my.telegram.org, open "API development tools", and create an app.',
              ),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open my.telegram.org'),
                onPressed: () => launchUrl(
                  Uri.parse('https://my.telegram.org'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              TextField(
                controller: _apiId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'api_id', border: OutlineInputBorder()),
              ),
              gap,
              TextField(
                controller: _apiHash,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'api_hash', border: OutlineInputBorder()),
              ),
              gap,
            ],
            if (!_hasBot) ...[
              Text('2. Bot', style: text.titleSmall),
              const Text("Make a bot with @BotFather and add it as an admin in your channel."),
              gap,
              TextField(
                controller: _token,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Bot token', border: OutlineInputBorder()),
              ),
              gap,
            ],
            Text('Channels', style: text.titleSmall),
            const InfoText(
              "One per line: a channel ID, @username or a post link. A link to the newest post works best. New device? Leave it empty and it copies everything from your other device on the same Wi-Fi.",
            ),
            gap,
            TextField(
              controller: _channels,
              minLines: 2,
              maxLines: 5,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: '-1001234567890\nhttps://t.me/c/1234567890/5678',
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            gap,
            FilledButton(
              onPressed: _running ? null : _start,
              child: Text(_running ? 'Working' : 'Start'),
            ),
            if (_running) ...[
              gap,
              ValueListenableBuilder(
                valueListenable: app.scanner.fraction,
                builder: (context, fraction, _) => LinearProgressIndicator(value: fraction),
              ),
              ValueListenableBuilder(
                valueListenable: app.scanner.progress,
                builder: (context, progress, _) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(progress ?? 'Connecting'),
                ),
              ),
            ],
            for (final r in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.ok ? Icons.check_circle : Icons.error,
                  color: r.ok ? null : Theme.of(context).colorScheme.error,
                  semanticLabel: r.ok ? 'Passed' : 'Failed',
                ),
                title: Text(r.label),
                subtitle: Text(r.detail),
              ),
            if (!_running && _anyAdded) ...[
              gap,
              FilledButton(onPressed: _openLibrary, child: const Text('Open library')),
            ],
          ],
        ),
      ),
    );
  }
}
