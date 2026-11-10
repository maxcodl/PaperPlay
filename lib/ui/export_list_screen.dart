import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../library/db.dart';
import '../library/missing_export.dart';
import 'widgets.dart';

/// Finds Spotify and Apple Music links for [tracks] (songs not found in the library) and keeps
/// them as a temporary list, then opens it. Shows how far it is, and Stop keeps what it has.
Future<void> exportMissingAsList(BuildContext context, String name, List<MissingTrack> tracks) async {
  if (tracks.isEmpty) return;
  final progress = ValueNotifier<(int, int)>((0, tracks.length));
  var stopped = false;
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => AlertDialog(
      title: const Text('Finding links'),
      content: ValueListenableBuilder<(int, int)>(
        valueListenable: progress,
        builder: (context, p, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.$1} of ${p.$2} songs'),
            const SizedBox(height: 4),
            Text(
              'Apple Music allows about 20 searches a minute, so this takes a while for a long list.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(minHeight: 8, value: p.$2 == 0 ? null : p.$1 / p.$2),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => stopped = true, child: const Text('Stop and keep what was found'))],
    ),
  ));
  final stamp = DateTime.now();
  final list = await buildExportList(
    tracks,
    '$name · ${stamp.day}/${stamp.month}',
    onProgress: (done, total) => progress.value = (done, total),
    cancelled: () => stopped,
  );
  navigator.pop(); // The progress dialog.
  progress.dispose();
  if (list.rows.isEmpty) return;
  await saveExportLists(app.db, [list, ...await loadExportLists(app.db)]);
  if (context.mounted) {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExportListScreen(listId: list.id)));
  }
}

/// The temporary lists on this device, each deletable.
class ExportListsScreen extends StatefulWidget {
  const ExportListsScreen({super.key});

  @override
  State<ExportListsScreen> createState() => _ExportListsScreenState();
}

class _ExportListsScreenState extends State<ExportListsScreen> {
  late Future<List<ExportList>> _lists = loadExportLists(app.db);

  void _reload() => setState(() => _lists = loadExportLists(app.db));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Temporary lists')),
        body: FutureBuilder<List<ExportList>>(
          future: _lists,
          builder: (context, snap) {
            final lists = snap.data;
            if (lists == null) return const Center(child: CircularProgressIndicator());
            if (lists.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No temporary lists. Open an imported playlist, then the songs not in your library, and choose Find links.'),
                ),
              );
            }
            return ListView(
              children: [
                for (final l in lists)
                  ListTile(
                    leading: const Icon(Icons.playlist_play_rounded),
                    title: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${l.rows.length} songs · ${l.withSpotify} on Spotify · ${l.withApple} on Apple Music'),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (!await confirm(context, 'Delete this list?', 'Only the list of links goes. Nothing else changes.', 'Delete')) return;
                        await deleteExportList(app.db, l.id);
                        _reload();
                      },
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ExportListScreen(listId: l.id)));
                      _reload();
                    },
                  ),
              ],
            );
          },
        ),
      );
}

/// One temporary list: the songs, links to open them, and ways to take the links out.
class ExportListScreen extends StatefulWidget {
  const ExportListScreen({super.key, required this.listId});
  final String listId;

  @override
  State<ExportListScreen> createState() => _ExportListScreenState();
}

class _ExportListScreenState extends State<ExportListScreen> {
  ExportList? _list;
  var _gone = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final found = (await loadExportLists(app.db)).where((l) => l.id == widget.listId).firstOrNull;
    if (!mounted) return;
    setState(() {
      _list = found;
      _gone = found == null;
    });
  }

  void _say(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) _say('Could not open the link.');
  }

  Future<void> _copy(ExportList list, {bool spotify = true, bool apple = true}) async {
    final text = exportLinks(list, spotify: spotify, apple: apple);
    if (text.isEmpty) {
      _say('No links of that kind.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _say('Links copied.');
  }

  Future<void> _save(ExportList list) async {
    final day = DateTime.now().toIso8601String().split('T').first;
    final saved = await FilePicker.saveFile(fileName: 'paperplay-missing-songs-$day.csv', bytes: utf8.encode(exportCsv(list)));
    _say(saved == null ? 'Not saved.' : 'Saved.');
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this list?', 'Only the list of links goes. Nothing else changes.', 'Delete')) return;
    await deleteExportList(app.db, widget.listId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? 'List', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (list != null) ...[
            PopupMenuButton<String>(
              tooltip: 'Copy or save',
              icon: const Icon(Icons.ios_share_rounded),
              onSelected: (v) => switch (v) {
                'all' => _copy(list),
                'spotify' => _copy(list, apple: false),
                'apple' => _copy(list, spotify: false),
                _ => _save(list),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'all', child: Text('Copy all links')),
                PopupMenuItem(value: 'spotify', child: Text('Copy Spotify links')),
                PopupMenuItem(value: 'apple', child: Text('Copy Apple Music links')),
                PopupMenuItem(value: 'csv', child: Text('Save as a file (CSV)')),
              ],
            ),
            IconButton(tooltip: 'Delete the list', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          ],
        ],
      ),
      body: list == null
          ? Center(child: _gone ? const Text('This list was deleted.') : const CircularProgressIndicator())
          : ListView(
              children: [
                ListTile(
                  title: Text('${list.rows.length} songs not in your library'),
                  subtitle: Text('${list.withSpotify} with a Spotify link · ${list.withApple} found on Apple Music. '
                      'A temporary list: delete it when you are done.'),
                ),
                for (final r in list.rows)
                  ListTile(
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      r.appleUrl == null ? '${r.artist} · not found on Apple Music' : r.artist,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Open in Spotify',
                          icon: const Icon(Icons.graphic_eq_rounded),
                          onPressed: r.spotifyUrl == null ? null : () => _open(r.spotifyUrl!),
                        ),
                        IconButton(
                          tooltip: 'Open in Apple Music',
                          icon: const Icon(Icons.music_note_rounded),
                          onPressed: r.appleUrl == null ? null : () => _open(r.appleUrl!),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
