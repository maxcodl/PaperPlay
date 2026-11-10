import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../app.dart';
import '../library/db.dart';
import '../library/scanner.dart';
import '../library/topic_sort.dart';
import '../library/upload.dart';
import 'channels_screen.dart' show mainFirst;
import 'topic_picker.dart';
import 'widgets.dart';

class _Target {
  const _Target(this.chatId, this.chatTitle, [this.topic]);
  final int chatId;
  final String chatTitle;
  final TopicChoice? topic;
}

class UploadsScreen extends StatelessWidget {
  const UploadsScreen({super.key});

  // chisle: the sheet's switch is shown from this until it reloads from the database.
  static bool? _asked;

  static const _channel = MethodChannel('teleplayer/audio_output');

  void _say(BuildContext context, String message) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Which channel to post to. Null if there's none, or the owner backed out.
  Future<LibraryChat?> _chooseChannel(BuildContext context) async {
    final chats = await app.db.select(app.db.libraryChats).get();
    final allowed = <LibraryChat>[];
    for (final c in chats) {
      if (await app.uploader.canPost(c.id)) allowed.add(c);
    }
    if (!context.mounted) return null;
    if (allowed.isEmpty) {
      _say(context, 'The bot can\'t post to any of your channels.');
      return null;
    }
    if (allowed.length == 1) return allowed.single;
    return showDialog<LibraryChat>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Upload to'),
        children: [
          for (final c in mainFirst(allowed, app.mainChat.value))
            SimpleDialogOption(onPressed: () => Navigator.pop(dialog, c), child: Text(c.title)),
        ],
      ),
    );
  }

  static const _askKey = 'upload_ask';

  /// Which channel, and which topic if it has them. Null if the owner backed out.
  ///
  /// With a main chat, everything goes to it without asking, to its General topic or to
  /// the chat itself if it has none. It's filed into topics once its info is in, so a
  /// song never needs a topic chosen up front.
  Future<_Target?> _chooseTarget(BuildContext context) async {
    final main = app.mainChat.value;
    if (main != null && await app.db.pref(_askKey) != 'true' && await app.uploader.canPost(main)) {
      return _Target(main, await app.db.chatTitle(main) ?? 'the main chat');
    }
    if (!context.mounted) return null;
    final chat = await _chooseChannel(context);
    if (chat == null) return null;
    final topics = await chatTopics(chat.id);
    if (topics.isEmpty) return _Target(chat.id, chat.title);
    if (!context.mounted) return null;
    final topic = await pickTopic(context, topics, 'Which topic?');
    return topic == null ? null : _Target(chat.id, chat.title, topic);
  }

  Future<void> _pickFiles(BuildContext context) async {
    final target = await _chooseTarget(context);
    if (target == null || !context.mounted) return;
    // Android's audio filter is what hides many formats, so it gets all files and
    // anything that isn't audio is left out afterwards.
    // After choosing, Android copies every picked file before handing it over, which can
    // take a minute for many songs with nothing on screen. Say so while it happens.
    final messenger = ScaffoldMessenger.of(context);
    void loading(FilePickerStatus status) {
      messenger.hideCurrentSnackBar();
      if (status == FilePickerStatus.picking) {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(minutes: 10),
            content: Row(
              children: [
                SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 16),
                Expanded(child: Text('Getting your files ready. Many songs can take a minute.')),
              ],
            ),
          ),
        );
      }
    }

    final picked = Platform.isAndroid
        ? await FilePicker.pickFiles(type: FileType.any, onFileLoading: loading)
        : await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: audioExtensions.toList(), onFileLoading: loading);
    messenger.hideCurrentSnackBar();
    final paths = picked.map((f) => f.path).whereType<String>().toList();
    await _queue(context, paths, target, temporary: Platform.isAndroid);
  }

  /// Checks every file is really audio, queues the ones that are and says what was left out.
  Future<void> _queue(BuildContext context, List<String> paths, _Target target, {bool temporary = false}) async {
    final checked = await checkAudio(paths);
    if (checked.audio.isNotEmpty) {
      app.uploader.enqueue(
        checked.audio,
        target.chatId,
        target.chatTitle,
        temporary: temporary,
        topicId: target.topic?.id,
        topicName: target.topic?.name,
      );
    }
    if (!context.mounted) return;
    final left = checked.rejected;
    _say(
      context,
      checked.audio.isEmpty
          ? 'No audio files found.'
          : '${_addedMessage(checked.audio.length, target)}'
              '${left == 0 ? '' : ' Left out $left file${left == 1 ? '' : 's'} that aren\'t audio.'}',
    );
  }

  /// Files or folders dropped on the desktop window. Goes to the main chat, or asks where.
  static Future<void> addDropped(BuildContext context, List<String> dropped) async {
    const screen = UploadsScreen();
    final paths = <String>[];
    for (final path in dropped) {
      if (FileSystemEntity.isDirectorySync(path)) {
        paths.addAll(await audioFilesIn(Directory(path)));
      } else {
        paths.add(path);
      }
    }
    if (paths.isEmpty || !context.mounted) return;
    final target = await screen._chooseTarget(context);
    if (target == null || !context.mounted) return;
    await screen._queue(context, paths, target);
  }

  Future<void> _pickFolder(BuildContext context) async {
    final target = await _chooseTarget(context);
    if (target == null) return;
    // Reading a whole folder directly needs this; a picked file doesn't.
    if (Platform.isAndroid) {
      final granted = await _channel.invokeMethod<bool>('requestAudioAccess') ?? false;
      if (!granted) {
        if (context.mounted) {
          _say(context, 'Paper Play needs access to your audio files to read a folder. You can still pick files.');
        }
        return;
      }
    }
    final folder = await FilePicker.getDirectoryPath();
    if (folder == null) return;
    if (context.mounted) _say(context, 'Looking through the folder...');
    final named = await audioFilesIn(Directory(folder));
    if (named.isEmpty) {
      if (context.mounted) _say(context, 'No audio files found in that folder.');
      return;
    }
    if (context.mounted) await _queue(context, named, target);
  }

  String _addedMessage(int count, _Target target) {
    final sorted = target.chatId == app.mainChat.value && target.topic == null;
    return 'Added $count songs. They upload one at a time${sorted ? ', then get sorted into topics' : ''}.';
  }

  void _chooseSource(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.audio_file_rounded),
                title: const Text('Choose songs'),
                subtitle: const Text('Pick one or several files'),
                onTap: () {
                  Navigator.pop(sheet);
                  _pickFiles(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: const Text('Upload a folder'),
                subtitle: const Text('Includes its subfolders'),
                onTap: () {
                  Navigator.pop(sheet);
                  _pickFolder(context);
                },
              ),
              if (app.mainChat.value != null)
                FutureBuilder<String?>(
                  future: app.db.pref(_askKey),
                  builder: (context, snap) => StatefulBuilder(
                    builder: (context, setSheet) {
                      final ask = snap.data == 'true';
                      return SwitchListTile(
                        secondary: const Icon(Icons.alt_route_rounded),
                        title: Row(children: [Flexible(child: Text('Choose where to upload each time')), const SizedBox(width: 4), InfoText("Off: songs go to your main chat and get sorted into topics.")]),
                        value: _asked ?? ask,
                        onChanged: (v) async {
                          await app.db.setPref(_askKey, '$v');
                          setSheet(() => _asked = v);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Uploads'),
          actions: [
            IconButton(
              tooltip: 'Clear finished',
              icon: const Icon(Icons.clear_all),
              onPressed: app.uploader.clearFinished,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload'),
          onPressed: () => _chooseSource(context),
        ),
        body: ValueListenableBuilder(
          valueListenable: app.uploader.jobs,
          builder: (context, jobs, _) => jobs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      "New songs go to your main chat (or the channel you pick) one at a time, then get sorted into topics. Keep Paper Play open till they're done.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _QueueBar(jobs: jobs),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: jobs.length,
                        itemBuilder: (context, i) => _JobTile(job: jobs[i]),
                      ),
                    ),
                  ],
                ),
        ),
      );
}

/// How far along the queue is, when the next file starts, and its controls.
class _QueueBar extends StatefulWidget {
  const _QueueBar({required this.jobs});
  final List<UploadJob> jobs;

  @override
  State<_QueueBar> createState() => _QueueBarState();
}

class _QueueBarState extends State<_QueueBar> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && app.uploader.nextAt.value != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _describe(int finished, int total, bool paused) {
    final base = '$finished of $total';
    if (paused) return '$base · Paused';
    final next = app.uploader.nextAt.value;
    if (next == null) return base;
    final seconds = next.difference(DateTime.now()).inSeconds.clamp(0, 99999);
    final wait = seconds >= 60 ? '${seconds ~/ 60} min ${seconds % 60}s' : '${seconds}s';
    return '$base · next in $wait';
  }

  @override
  Widget build(BuildContext context) {
    final jobs = widget.jobs;
    final finished = jobs.where((j) => j.status != UploadStatus.queued && j.status != UploadStatus.uploading).length;
    final waiting = jobs.any((j) => j.status == UploadStatus.queued);
    return ValueListenableBuilder(
      valueListenable: app.uploader.paused,
      builder: (context, paused, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _describe(finished, jobs.length, paused),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (waiting || paused)
              IconButton(
                tooltip: paused ? 'Resume' : 'Pause after this song',
                icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                onPressed: () => app.uploader.setPaused(!paused),
              ),
            if (waiting)
              IconButton(
                tooltip: 'Cancel what\'s waiting',
                icon: const Icon(Icons.cancel_outlined),
                onPressed: app.uploader.cancelWaiting,
              ),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});
  final UploadJob job;

  @override
  Widget build(BuildContext context) {
    final where = [job.chatTitle, ?job.topicName].join(' · ');
    return ListTile(
        title: Text(p.basename(job.path), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: switch (job.status) {
          UploadStatus.queued => Text('Waiting · $where', maxLines: 1, overflow: TextOverflow.ellipsis),
          UploadStatus.uploading => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(where, maxLines: 1, overflow: TextOverflow.ellipsis),
                LinearProgressIndicator(value: job.progress),
              ],
            ),
          UploadStatus.done => Text('Uploaded to $where', maxLines: 1, overflow: TextOverflow.ellipsis),
          UploadStatus.skipped => Text('Already in your library · not sent to $where', maxLines: 1, overflow: TextOverflow.ellipsis),
          UploadStatus.failed => Text('$where · ${job.error ?? 'Failed'}'),
        },
        trailing: switch (job.status) {
          UploadStatus.failed => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => app.uploader.retry(job),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => app.uploader.remove(job),
                ),
              ],
            ),
          UploadStatus.queued => IconButton(
              tooltip: 'Don\'t upload this',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => app.uploader.remove(job),
            ),
          _ => null,
        },
      );
  }
}
