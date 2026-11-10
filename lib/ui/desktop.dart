import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../library/db.dart';
import 'devices.dart';
import 'mixes.dart';
import 'player_screen.dart';
import 'playlists.dart';
import 'quality_badge.dart';
import 'tasks_screen.dart';
import 'uploads.dart' show UploadsScreen;
import 'widgets.dart';

/// At this width the app uses panels and a fixed player bar.
const desktopWidth = 1000.0;

/// The side panel needs this much width to leave room for the list.
const _panelWidth = 1200.0;

const _gap = 8.0;

bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktopWidth;

/// Hands the current page to the nested navigator's first route, which would
/// otherwise keep the widgets it was first built with.
class _Page extends InheritedWidget {
  const _Page({required this.page, required super.child});
  final Widget page;

  @override
  bool updateShouldNotify(_Page old) => page != old.page;
}

/// A section of the sidebar. Home is 0, Search 1, Library 2 with [library] as its tab.
typedef SelectSection = void Function(int section, [int? library]);

/// Sidebar, a content panel with its own page history, the current song's panel,
/// and a player bar that stays visible on every page.
class DesktopShell extends StatefulWidget {
  const DesktopShell({
    super.key,
    required this.section,
    required this.library,
    required this.onSelect,
    required this.page,
  });

  final int section, library;
  final SelectSection onSelect;
  final Widget page;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final _nav = GlobalKey<NavigatorState>();
  var _dragging = false;

  void _toRoot() => _nav.currentState?.popUntil((r) => r.isFirst);

  void _openPage(Widget page) {
    _toRoot();
    _nav.currentState?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final panel = scheme.surfaceContainerLow;
    // Everything inside the panels sits on the panel, not the window behind it.
    final panelTheme = theme.copyWith(
      scaffoldBackgroundColor: panel,
      appBarTheme: theme.appBarTheme.copyWith(backgroundColor: Colors.transparent),
    );
    final width = MediaQuery.sizeOf(context).width;
    return ValueListenableBuilder(
      valueListenable: app.ui.coverGradient,
      builder: (context, gradient, _) => _dropTarget(context, theme, scheme, panel, panelTheme, width, gradient),
    );
  }

  Widget _dropTarget(BuildContext context, ThemeData theme, ColorScheme scheme, Color panel, ThemeData panelTheme,
      double width, bool gradient) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) {
        setState(() => _dragging = false);
        UploadsScreen.addDropped(context, [for (final f in d.files) f.path]);
      },
      child: Stack(
        children: [
          Positioned.fill(child: _shell(scheme, gradient ? panel.withValues(alpha: 0.72) : panel, panelTheme, width, gradient)),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.scrim.withValues(alpha: 0.55),
                  child: Center(
                    child: Text('Drop songs or folders to upload', style: theme.textTheme.headlineSmall),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shell(ColorScheme scheme, Color panel, ThemeData panelTheme, double width, bool gradient) {
    return Scaffold(
      backgroundColor: gradient ? Colors.transparent : scheme.surfaceContainerLowest,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_gap, _gap, _gap, 0),
              child: Row(
                children: [
                  _Panel(
                    color: panel,
                    width: 248,
                    child: _Sidebar(
                      section: widget.section,
                      library: widget.library,
                      onSelect: (s, [l]) {
                        _toRoot();
                        widget.onSelect(s, l);
                      },
                      onOpen: _openPage,
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: _Panel(
                      color: panel,
                      child: Theme(
                        data: panelTheme,
                        child: _Page(
                          page: widget.page,
                          child: Navigator(
                            key: _nav,
                            onGenerateRoute: (_) => MaterialPageRoute<void>(
                              builder: (context) => context.dependOnInheritedWidgetOfExactType<_Page>()!.page,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([app.ui.nowPlayingPanel, app.player.current]),
                    builder: (context, _) {
                      final song = app.player.current.value;
                      if (song == null || !app.ui.nowPlayingPanel.value || width < _panelWidth) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(left: _gap),
                        child: _Panel(color: panel, width: 320, child: _NowPlayingPanel(song: song)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const DesktopPlayerBar(),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.child, this.width});
  final Color color;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.library,
    required this.onSelect,
    required this.onOpen,
  });

  final int section, library;
  final SelectSection onSelect;
  final ValueChanged<Widget> onOpen;

  bool _isLibrary(int tab) => section == 2 && library == tab;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Playlist>>(
        stream: app.db.watchPlaylists(),
        builder: (context, snap) => ListView(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          children: [
            _SideItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: section == 0,
              onTap: () => onSelect(0),
            ),
            _SideItem(
              icon: Icons.search_rounded,
              label: 'Search',
              selected: section == 1,
              onTap: () => onSelect(1),
            ),
            _SideItem(
              icon: Icons.account_circle_rounded,
              label: 'Profile',
              selected: section == 3,
              onTap: () => onSelect(3),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([app.tasks.live, app.tasks.remote]),
              builder: (context, _) {
                final n = app.tasks.live.value.length + app.tasks.remote.value.values.fold(0, (a, l) => a + l.length);
                return _SideItem(
                  icon: Icons.task_alt_rounded,
                  label: 'Tasks',
                  badge: n == 0 ? null : '$n running',
                  onTap: () => onOpen(const TasksScreen()),
                );
              },
            ),
            const _SideHeading('Your library'),
            _SideItem(
              icon: Icons.music_note_rounded,
              label: 'Songs',
              selected: _isLibrary(0),
              onTap: () => onSelect(2, 0),
            ),
            _SideItem(
              icon: Icons.album_rounded,
              label: 'Albums',
              selected: _isLibrary(1),
              onTap: () => onSelect(2, 1),
            ),
            _SideItem(
              icon: Icons.person_rounded,
              label: 'Artists',
              selected: _isLibrary(2),
              onTap: () => onSelect(2, 2),
            ),
            _SideItem(
              icon: Icons.favorite_rounded,
              label: 'Favorites',
              onTap: () => onOpen(smartList('Favorites', app.db.watchFavorites())),
            ),
            _SideItem(
              icon: Icons.history_rounded,
              label: 'Recently played',
              onTap: () => onOpen(smartList('Recently played', app.db.watchRecent())),
            ),
            _SideHeading(
              'Playlists',
              trailing: IconButton(
                tooltip: 'Playlists and import',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: () => onSelect(2, 3),
              ),
            ),
            for (final p in snap.data ?? const <Playlist>[])
              _SideItem(
                leading: PlaylistArt(playlistId: p.id, size: 28, radius: 5),
                label: p.name,
                onTap: () => onOpen(PlaylistScreen(playlist: p)),
              ),
            StreamBuilder<List<ForumTopic>>(
              stream: app.db.watchTopics(),
              builder: (context, topics) {
                final list = mainChatTopics(topics.data);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (list.isNotEmpty) const _SideHeading('Telegram topics'),
                    for (final t in list)
                      _SideItem(
                        leading: TopicArt(topic: t, size: 28, radius: 5),
                        label: topicName(t),
                        onTap: () => onOpen(
                          smartList(topicName(t), app.db.watchTopicSongs(t.chatId, t.topicId)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _SideHeading extends StatelessWidget {
  const _SideHeading(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 4, 4),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({this.icon, this.leading, required this.label, required this.onTap, this.selected = false, this.badge});
  final IconData? icon;

  /// Small text at the end of the row, such as how many tasks are running.
  final String? badge;

  /// Art to show in place of [icon].
  final Widget? leading;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                leading ?? Icon(icon, color: selected ? scheme.primary : color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
                if (badge != null)
                  Text(badge!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The current song while browsing, with what plays after it.
class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ValueListenableBuilder(
      valueListenable: app.player.queue,
      builder: (context, queue, _) {
        final at = queue.indexWhere((s) => s.uniqueId == song.uniqueId);
        final next = at == -1 ? const <Song>[] : queue.skip(at + 1).take(10).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    // A single's album only repeats the title below it.
                    song.album.isEmpty || song.album.startsWith(song.title) ? 'Now playing' : song.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Hide this panel',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => app.ui.setNowPlayingPanel(false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openPlayer(context),
              child: LayoutBuilder(
                builder: (context, box) => Cover(song, size: box.maxWidth, radius: 12),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(song.artist, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: song.favorite ? 'Remove from favorites' : 'Add to favorites',
                  isSelected: song.favorite,
                  icon: const Icon(Icons.favorite_border_rounded),
                  selectedIcon: const Icon(Icons.favorite_rounded),
                  onPressed: () => app.player.toggleFavorite(song),
                ),
              ],
            ),
            const SizedBox(height: 6),
            QualityLabel(song, detailed: true, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            if (song.year != null || song.genre != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [if (song.year != null) '${song.year}', if (song.genre != null) song.genre!].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Up next', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final (i, s) in next.indexed)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => app.player.out.seek(Duration.zero, index: at + 1 + i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Cover(s, size: 40, radius: 6),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                              Text(
                                s.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// The always-visible player: song on the left, controls in the middle, and
/// output, queue and volume on the right.
class DesktopPlayerBar extends StatelessWidget {
  const DesktopPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final out = app.player.out;
    return SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Expanded(flex: 3, child: _BarSong()),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ShuffleButton(),
                      IconButton(
                        tooltip: 'Previous (Ctrl+Left)',
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: out.seekToPrevious,
                      ),
                      const SizedBox(width: 4),
                      const PlayPauseButton(circle: true),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Next (Ctrl+Right)',
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: out.seekToNext,
                      ),
                      const LoopButton(),
                    ],
                  ),
                  const _SeekRow(),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder(
                    valueListenable: app.ui.nowPlayingPanel,
                    builder: (context, on, _) => IconButton(
                      tooltip: on ? 'Hide now playing' : 'Show now playing',
                      isSelected: on,
                      icon: const Icon(Icons.view_sidebar_outlined),
                      selectedIcon: const Icon(Icons.view_sidebar_rounded),
                      onPressed: () => app.ui.setNowPlayingPanel(!on),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Queue',
                    icon: const Icon(Icons.queue_music_rounded),
                    onPressed: () => showQueue(context),
                  ),
                  const DeviceButton(),
                  const _VolumeControl(),
                  IconButton(
                    tooltip: 'Full screen player',
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    onPressed: () {
                      if (app.player.current.value != null) openPlayer(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarSong extends StatelessWidget {
  const _BarSong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: app.player.current,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();
        return Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => openPlayer(context),
              child: Hero(tag: 'now-playing-cover', child: Cover(song, size: 58, radius: 8)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const PlayingOnLabel(),
                ],
              ),
            ),
            IconButton(
              tooltip: song.favorite ? 'Remove from favorites' : 'Add to favorites',
              isSelected: song.favorite,
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              onPressed: () => app.player.toggleFavorite(song),
            ),
          ],
        );
      },
    );
  }
}

/// A slim slider that only shows its handle and accent while the mouse is over it.
class _HoverSlider extends StatefulWidget {
  const _HoverSlider({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    required this.label,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double) label;

  @override
  State<_HoverSlider> createState() => _HoverSliderState();
}

class _HoverSliderState extends State<_HoverSlider> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: _hover ? scheme.primary : scheme.onSurface,
          inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.22),
          thumbColor: scheme.onSurface,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: _hover ? 6 : 0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: widget.value.clamp(0.0, 1.0),
          semanticFormatterCallback: widget.label,
          onChanged: widget.onChanged,
          onChangeEnd: widget.onChangeEnd,
        ),
      ),
    );
  }
}

class _SeekRow extends StatefulWidget {
  const _SeekRow();

  @override
  State<_SeekRow> createState() => _SeekRowState();
}

class _SeekRowState extends State<_SeekRow> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final out = app.player.out;
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return StreamBuilder<Duration>(
      stream: out.positionStream,
      builder: (context, snap) {
        final total = out.duration ?? Duration.zero;
        final ms = total.inMilliseconds;
        final position = snap.data ?? Duration.zero;
        final value = _dragging ?? (ms > 0 ? position.inMilliseconds / ms : 0.0);
        final shown = _dragging == null ? position : total * _dragging!;
        return SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(width: 44, child: Text(formatDuration(shown), textAlign: TextAlign.end, style: style)),
              Expanded(
                child: _HoverSlider(
                  value: value,
                  label: (v) => '${formatDuration(total * v)} of ${formatDuration(total)}',
                  onChanged: ms > 0 ? (v) => setState(() => _dragging = v) : null,
                  onChangeEnd: (v) {
                    out.seek(total * v);
                    setState(() => _dragging = null);
                  },
                ),
              ),
              SizedBox(width: 44, child: Text(formatDuration(total), style: style)),
            ],
          ),
        );
      },
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl();

  @override
  Widget build(BuildContext context) {
    final out = app.player.out;
    return StreamBuilder<double>(
      stream: out.volumeStream,
      builder: (context, snap) {
        final volume = snap.data ?? 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: volume == 0 ? 'Unmute (M)' : 'Mute (M)',
              icon: Icon(
                volume == 0
                    ? Icons.volume_off_rounded
                    : volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
              ),
              onPressed: () => out.setVolume(volume == 0 ? 1 : 0),
            ),
            SizedBox(
              width: 96,
              child: _HoverSlider(
                value: volume,
                label: (v) => 'Volume ${(v * 100).round()}%',
                onChanged: out.setVolume,
              ),
            ),
          ],
        );
      },
    );
  }
}

const _indexWidth = 36.0, _favoriteWidth = 40.0, _lengthWidth = 52.0, _menuWidth = 48.0;
const _titleFlex = 5, _albumFlex = 3;

/// Headings above the desktop song rows, lined up with their columns.
class DesktopSongHeader extends StatelessWidget {
  const DesktopSongHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: _indexWidth, child: Text('#', textAlign: TextAlign.center, style: style)),
              const SizedBox(width: 12),
              Expanded(flex: _titleFlex, child: Text('Title', style: style)),
              const SizedBox(width: 16),
              Expanded(flex: _albumFlex, child: Text('Album', style: style)),
              const SizedBox(width: _favoriteWidth),
              SizedBox(
                width: _lengthWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.schedule_rounded, size: 16, color: style?.color, semanticLabel: 'Length'),
                ),
              ),
              const SizedBox(width: _menuWidth),
            ],
          ),
        ),
      ),
    );
  }
}

/// A desktop song row: its number becomes a play icon, and its actions appear,
/// while the mouse is over it.
class DesktopSongRow extends StatefulWidget {
  const DesktopSongRow({super.key, required this.songs, required this.index, this.playlistId});
  final List<Song> songs;
  final int index;
  final int? playlistId;

  @override
  State<DesktopSongRow> createState() => _DesktopSongRowState();
}

class _DesktopSongRowState extends State<DesktopSongRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.songs[widget.index];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: ValueListenableBuilder(
          valueListenable: selection,
          builder: (context, picked, child) => Material(
            color: picked.contains(widget.songs[widget.index].uniqueId)
                ? scheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          child: InkWell(
            hoverColor: scheme.onSurface.withValues(alpha: 0.07),
            // While songs are picked, a click picks; long-press or right-click starts picking.
            onTap: () => selection.value.isEmpty
                ? app.player.play(widget.songs, widget.index)
                : toggleSelected(widget.songs[widget.index]),
            onLongPress: () => toggleSelected(widget.songs[widget.index]),
            onSecondaryTap: () => toggleSelected(widget.songs[widget.index]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ValueListenableBuilder(
                valueListenable: app.player.current,
                builder: (context, current, _) {
                  final playing = current?.uniqueId == song.uniqueId;
                  return Row(
                    children: [
                      SizedBox(
                        width: _indexWidth,
                        child: Center(
                          child: _hover
                              ? Icon(Icons.play_arrow_rounded, size: 22, color: scheme.onSurface)
                              : playing
                                  ? Icon(Icons.graphic_eq_rounded, size: 20, color: scheme.primary, semanticLabel: 'Playing')
                                  : Text(
                                      '${widget.index + 1}',
                                      style: muted?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Cover(song, size: 40, radius: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: _titleFlex,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(color: playing ? scheme.primary : null),
                            ),
                            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: _albumFlex,
                        child: Text(song.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                      ),
                      SizedBox(
                        width: _favoriteWidth,
                        child: song.favorite || _hover
                            ? IconButton(
                                tooltip: song.favorite ? 'Remove from favorites' : 'Add to favorites',
                                isSelected: song.favorite,
                                iconSize: 18,
                                icon: const Icon(Icons.favorite_border_rounded),
                                selectedIcon: const Icon(Icons.favorite_rounded),
                                onPressed: () => app.player.toggleFavorite(song),
                              )
                            : null,
                      ),
                      SizedBox(
                        width: _lengthWidth,
                        child: Text(
                          formatDuration(Duration(seconds: song.durationSec)),
                          textAlign: TextAlign.end,
                          style: muted?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                      SizedBox(
                        width: _menuWidth,
                        child: Opacity(
                          opacity: _hover ? 1 : 0,
                          child: SongMenu(song: song, playlistId: widget.playlistId),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
