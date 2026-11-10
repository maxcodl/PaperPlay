import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../library/db.dart';
import '../library/missing_info.dart';
import 'missing_info_screen.dart';
import 'widgets.dart';

/// Thin progress strip on the home screen; hidden when nothing is happening. It says
/// what the app is busy with and how far along it is, the same as the notification.
class StatusBanner extends StatefulWidget {
  const StatusBanner({super.key});

  @override
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner> {
  late final Listenable _sources = Listenable.merge([
    app.scanner.progress,
    app.scanner.fraction,
    app.mover.jobs,
    app.mover.paused,
    app.filer.mover.jobs,
    app.filer.mover.paused,
    app.uploader.jobs,
    app.uploader.paused,
    app.enricher.run,
    app.enricher.coversQueued,
    app.enricher.coversBatch,
    app.stats,
    app.moodScanned,
    app.taste,
  ]);

  @override
  void initState() {
    super.initState();
    _sources.addListener(_changed);
  }

  @override
  void dispose() {
    _sources.removeListener(_changed);
    super.dispose();
  }

  /// A change that lands while the screen is being laid out would swap the strip's contents
  /// mid-layout, which leaves its new boxes unmeasured ("RenderBox was not laid out"). So
  /// during a frame it waits for the frame to finish.
  void _changed() {
    if (!mounted) return;
    final binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = app.activity();
    if (!a.busy) return const SizedBox.shrink();
    final measured = a.done != null && a.total != null && a.total! > 0;
    return Column(
      children: [
        LinearProgressIndicator(value: measured ? a.done! / a.total! : null),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            [a.title, if (a.detail.isNotEmpty) a.detail.replaceAll('\n', ' · ')].join(' · '),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Library breakdown for Settings.
class LibraryStatusTiles extends StatelessWidget {
  const LibraryStatusTiles({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<LibraryStats>(
        stream: app.db.watchStats(),
        builder: (context, snap) {
          final s = snap.data;
          if (s == null) return const SizedBox.shrink();
          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.library_music),
                title: Text('${s.total} songs'),
                subtitle: Text(
                  'Song info: ${s.matched} found, ${s.noMatch} with no match, ${s.waiting} waiting',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: Row(children: [Flexible(child: Text('Covers: ${s.covers} of ${s.total}')), const SizedBox(width: 4), InfoText("Covers load as songs show up on screen, from the Telegram file or online once the song is matched. No match? Try \"Find metadata\" in the song menu.")]),
              ),
              ValueListenableBuilder(
                valueListenable: app.liveSongs,
                builder: (context, songs, _) {
                  final lookups = app.taste.value.lookups;
                  final left = songs.values.where((x) => missingOf(x, lookupsOn: lookups).isNotEmpty).length;
                  return ListTile(
                    leading: const Icon(Icons.checklist_rounded),
                    title: const Text('Song info left'),
                    subtitle: Text(
                      left == 0
                          ? 'Every song is complete'
                          : '$left of ${songs.length} songs lack something. Tap to see which, and what.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const MissingInfoScreen()),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
}
