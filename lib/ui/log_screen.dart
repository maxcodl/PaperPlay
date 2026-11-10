import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../log.dart';

/// Everything the app has logged, newest first.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late final Timer _refresh;
  var _seen = appLog.version;
  var _problemsOnly = false;
  String? _source;
  var _search = '';

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (appLog.version != _seen) setState(() => _seen = appLog.version);
    });
  }

  @override
  void dispose() {
    _refresh.cancel();
    super.dispose();
  }

  Future<void> _save(String name, String text, String what) async {
    final messenger = ScaffoldMessenger.of(context);
    if (text.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('The $what is empty')));
      return;
    }
    try {
      final day = DateTime.now().toIso8601String().split('T').first;
      final saved = await FilePicker.saveFile(fileName: '$name-$day.txt', bytes: Uint8List.fromList(utf8.encode(text)));
      messenger.showSnackBar(SnackBar(content: Text(saved == null ? 'Not saved' : 'Saved the $what')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Couldn\'t save: $e')));
    }
  }

  bool _shown(LogEntry e) =>
      (!_problemsOnly || e.level != LogLevel.info) &&
      (_source == null || e.source == _source) &&
      (_search.isEmpty || e.message.toLowerCase().contains(_search));

  static String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = appLog.entries;
    final sources = {for (final e in all) e.source}.toList()..sort();
    final shown = all.where(_shown).toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity log'),
        actions: [
          IconButton(
            tooltip: 'Copy what\'s shown',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              // The newest lines, oldest first: a long paste gets cut off at the end, and
              // the streaming checks would bury everything else.
              final recent = shown
                  .where((e) => !e.message.startsWith('getFileDownloadedPrefixSize'))
                  .take(1500)
                  .toList()
                  .reversed;
              await Clipboard.setData(ClipboardData(text: recent.map((e) => e.line).join('\n')));
              messenger.showSnackBar(SnackBar(content: Text('Copied the latest ${recent.length} lines')));
            },
          ),
          IconButton(
            tooltip: 'Save the whole log as a text file',
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: () => _save('teleplayer-log', appLog.allText, 'log'),
          ),
          IconButton(
            tooltip: 'Save the crash log as a text file',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () async => _save('teleplayer-crashes', await appLog.crashText(), 'crash log'),
          ),
          IconButton(
            tooltip: 'Clear the log',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await appLog.clear();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search the log',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Problems only'),
                  selected: _problemsOnly,
                  onSelected: (v) => setState(() => _problemsOnly = v),
                ),
                for (final s in sources)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _source == s,
                      onSelected: (on) => setState(() => _source = on ? s : null),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${shown.length} of ${all.length} lines', style: theme.textTheme.labelMedium),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('Nothing to show'))
                : SelectionArea(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, i) => _Line(shown[i], _time(shown[i].time)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.entry, this.time);
  final LogEntry entry;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = switch (entry.level) {
      LogLevel.info => scheme.onSurface,
      LogLevel.warning => scheme.tertiary,
      LogLevel.error => scheme.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$time · ${entry.source}${entry.level == LogLevel.info ? '' : ' · ${entry.level.name}'}',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Text(entry.message, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
