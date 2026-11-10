import 'package:flutter/material.dart';

import '../library/auto_filer.dart';
import '../app.dart';
import '../library/db.dart';
import '../library/missing_info.dart';
import '../metadata/enricher.dart';
import 'widgets.dart';

/// Every song that still lacks something, and what, so nothing is left to guess at.
class MissingInfoScreen extends StatefulWidget {
  const MissingInfoScreen({super.key});

  @override
  State<MissingInfoScreen> createState() => _MissingInfoScreenState();
}

class _MissingInfoScreenState extends State<MissingInfoScreen> {
  Missing? _only;

  String _status() {
    final covers = app.enricher.coversQueued.value;
    final parts = [
      switch (app.enricher.run.value) {
        EnrichRun.running => 'Looking up song info now',
        EnrichRun.paused => 'Song info paused: a source is busy or unreachable. Trying again every minute',
        EnrichRun.idle => 'No song info lookup running',
      },
      if (covers > 0) 'Loading $covers covers',
    ];
    return parts.join(' · ');
  }

  /// The songs on screen, so "Look up again" only redoes what's selected or filtered.
  var _shownSongs = const <Song>[];

  Future<void> _again() async {
    final picked = selection.value;
    final songs = picked.isEmpty ? _shownSongs : [for (final s in _shownSongs) if (picked.contains(s.uniqueId)) s];
    final n = await app.enricher.retrySongs(songs);
    selection.value = const {};
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(n == 0 ? 'Nothing to look up.' : 'Looking up $n songs again, info and covers.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Song info left')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: Listenable.merge([app.liveSongs, app.taste, app.enricher.run, app.enricher.coversQueued, selection]),
              builder: (context, _) {
                final lookups = app.taste.value.lookups;
                // One row per song, as in the library, not one per version.
                final all = oneVersionEach(app.liveSongs.value.values.toList(), app.mainChat.value);
                final rows = [
                  for (final s in all) (song: s, missing: missingOf(s, lookupsOn: lookups)),
                ].where((r) => r.missing.isNotEmpty).toList();
                final counts = {
                  for (final m in Missing.values) m: rows.where((r) => r.missing.contains(m)).length,
                };
                final shown = (_only == null ? rows : rows.where((r) => r.missing.contains(_only)).toList())
                  ..sort((a, b) {
                    final byCount = b.missing.length.compareTo(a.missing.length);
                    return byCount != 0 ? byCount : a.song.title.compareTo(b.song.title);
                  });
                _shownSongs = [for (final r in shown) r.song];
                return Column(
                  children: [
                    SelectionBar(songs: _shownSongs),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
                        itemCount: shown.length + 1,
                        itemBuilder: (context, i) => i == 0
                            ? _header(all.length, rows.length, counts)
                            : _row(shown[i - 1].song, shown[i - 1].missing),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _header(int total, int incomplete, Map<Missing, int> counts) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            incomplete == 0 ? 'All $total songs are complete' : '${total - incomplete} of $total songs are complete',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(_status(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in Missing.values)
                if (counts[m]! > 0)
                  FilterChip(
                    label: Text('${m.label} (${counts[m]})'),
                    selected: _only == m,
                    onSelected: (on) => setState(() => _only = on ? m : null),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _again,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Look up again'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Redoes only the songs shown by the chosen filter, or the ones you selected. Songs you edited keep their info.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (incomplete > 0) const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _row(Song song, Set<Missing> missing) {
    final scheme = Theme.of(context).colorScheme;
    final picked = selection.value.contains(song.uniqueId);
    return ListTile(
      selected: picked,
      selectedTileColor: scheme.secondaryContainer,
      leading: picked
          ? SizedBox.square(dimension: 44, child: Icon(Icons.check_circle_rounded, color: scheme.primary))
          : Cover(song, size: 44, radius: 8),
      // Find metadata, change cover, delete and the rest.
      trailing: SongMenu(song: song),
      onLongPress: () => toggleSelected(song),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final m in Missing.values)
                if (missing.contains(m))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: m.todo ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: m.todo ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
            ],
          ),
        ],
      ),
      onTap: () => selection.value.isEmpty ? showSongInfo(context, song) : toggleSelected(song),
    );
  }
}
