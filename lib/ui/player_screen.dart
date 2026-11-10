import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icon_button_m3e/icon_button_m3e.dart';
import 'package:just_audio/just_audio.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import '../app.dart';
import '../library/db.dart';
import '../metadata/enricher.dart';
import 'cover_colors.dart';
import 'devices.dart';
import 'quality_badge.dart';
import 'theme.dart';
import 'wavy_seek.dart';
import 'widgets.dart';

const _heroTag = 'now-playing-cover';

/// Opens the player with a slide up, so it feels attached to the mini player.
void openPlayer(BuildContext context) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => const PlayerScreen(),
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ).drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
      child: child,
    ),
  ),
);

/// Play and pause morph into each other. Shows a loading shape while buffering.
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, this.large = false, this.circle = false});
  final bool large;

  /// A small filled circle in the text colour, for the desktop bar.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final player = app.player.out;
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snap) {
        final state = snap.data;
        final loading =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        final playing = state?.playing ?? false;
        final glyph = TweenAnimationBuilder<double>(
          tween: Tween(end: playing ? 1 : 0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          builder: (context, v, _) => AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: AlwaysStoppedAnimation(v),
            size: large ? 32 : 28,
          ),
        );
        final tooltip = playing ? 'Pause' : 'Play';
        final onPressed = playing ? player.pause : player.play;
        if (circle) {
          final scheme = Theme.of(context).colorScheme;
          return IconButton.filled(
            tooltip: '$tooltip (Space)',
            style: IconButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              fixedSize: const Size.square(40),
              minimumSize: const Size.square(40),
              padding: EdgeInsets.zero,
            ),
            icon: loading
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface),
                  )
                : glyph,
            onPressed: onPressed,
          );
        }
        if (!large) {
          return IconButton(
            tooltip: tooltip,
            icon: glyph,
            onPressed: onPressed,
          );
        }
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButtonM3E(
              variant: IconButtonM3EVariant.filled,
              size: IconButtonM3ESize.md,
              // Never "selected", which would turn it square while playing.
              icon: glyph,
              tooltip: tooltip,
              onPressed: onPressed,
            ),
            if (loading)
              const IgnorePointer(
                child: SizedBox.square(
                  dimension: 72,
                  child: LoadingIndicatorM3E(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  ColorScheme? _scheme;
  String? _coverPath;

  /// Wider than this, the song and its lyrics or queue sit side by side.
  static const _wideFrom = 900.0;

  @override
  void initState() {
    super.initState();
    app.player.current.addListener(_loadColors);
    _loadColors();
  }

  @override
  void dispose() {
    app.player.current.removeListener(_loadColors);
    super.dispose();
  }

  Future<void> _loadColors() async {
    final path = app.player.current.value?.coverPath;
    if (path == null || path == _coverPath) return;
    _coverPath = path;
    final scheme = await coverScheme(path, Brightness.dark);
    if (mounted && _coverPath == path) setState(() => _scheme = scheme);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    final scheme =
        _scheme ??
        ColorScheme.fromSeed(
          seedColor: base.primary,
          brightness: Brightness.dark,
        );
    final wide = MediaQuery.sizeOf(context).width >= _wideFrom;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedTheme(
        data: buildTheme(scheme, amoled: false),
        duration: const Duration(milliseconds: 500),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(scheme.primaryContainer, Colors.black, 0.25)!,
                      Color.lerp(scheme.surfaceContainerLow, Colors.black, 0.75)!,
                      Colors.black,
                    ],
                    stops: const [0, 0.6, 1],
                  ),
                ),
              ),
              if (wide && _coverPath != null) _BlurredCover(path: _coverPath!),
              SafeArea(
                child: ValueListenableBuilder(
                  valueListenable: app.player.current,
                  builder: (context, song, _) => song == null
                      ? const SizedBox.shrink()
                      : wide
                          ? _PlayerWide(song: song)
                          : _PlayerBody(song: song),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cover, heavily blurred and darkened, filling a large window with its
/// colours. A gradient alone looks empty at this size.
class _BlurredCover extends StatelessWidget {
  const _BlurredCover({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 600),
    child: Stack(
      key: ValueKey(path),
      fit: StackFit.expand,
      children: [
        // Kept apart from the seek bar, which redraws every frame.
        RepaintBoundary(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 256,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const ColoredBox(color: Color(0x99000000)),
      ],
    ),
  );
}

/// The player in a large window: the song on the left, its lyrics or the queue
/// on the right.
class _PlayerWide extends StatefulWidget {
  const _PlayerWide({required this.song});
  final Song song;

  @override
  State<_PlayerWide> createState() => _PlayerWideState();
}

class _PlayerWideState extends State<_PlayerWide> {
  var _showQueue = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final theme = Theme.of(context);
    final player = app.player.out;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close player (Esc)',
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              const PlayingOnLabel(),
              const SizedBox(width: 8),
              const DeviceButton(),
              ValueListenableBuilder(
                valueListenable: app.player.sleepAt,
                builder: (context, sleepAt, _) => IconButton(
                  tooltip: sleepAt == null ? 'Sleep timer and speed' : 'Sleep timer on',
                  isSelected: sleepAt != null,
                  icon: const Icon(Icons.bedtime_outlined),
                  selectedIcon: const Icon(Icons.bedtime_rounded),
                  onPressed: () => _showSleepAndSpeed(context),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 0, 48, 24),
            child: LayoutBuilder(
              builder: (context, box) {
                const below = 236.0;
                final art = min(box.maxWidth * 0.42, box.maxHeight - below).clamp(160.0, 620.0);
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: SizedBox(
                          width: max(art, 360.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Artwork(song: song, size: art),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.headlineSmall,
                                        ),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
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
                                  SongMenu(song: song, icon: Icons.more_horiz_rounded),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _Progress(song: song),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const ShuffleButton(),
                                  IconButton(
                                    tooltip: 'Previous (Ctrl+Left)',
                                    iconSize: 38,
                                    icon: const Icon(Icons.skip_previous_rounded),
                                    onPressed: player.seekToPrevious,
                                  ),
                                  const PlayPauseButton(large: true),
                                  IconButton(
                                    tooltip: 'Next (Ctrl+Right)',
                                    iconSize: 38,
                                    icon: const Icon(Icons.skip_next_rounded),
                                    onPressed: player.seekToNext,
                                  ),
                                  const LoopButton(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Lyrics'),
                                selected: !_showQueue,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _showQueue = false),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Up next'),
                                selected: _showQueue,
                                showCheckmark: false,
                                onSelected: (_) => setState(() => _showQueue = true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _showQueue
                                ? const QueueView()
                                : LyricsView(key: ValueKey(song.uniqueId), song: song),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerBody extends StatelessWidget {
  const _PlayerBody({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = app.player.out;
    // Icon buttons have 12dp of empty space around their glyphs. Laying out on a
    // 12dp margin and insetting everything else by 12 lines the glyphs up with
    // the edges of the cover and seek bar, all on one 24dp margin.
    const inset = EdgeInsets.symmetric(horizontal: 12);
    return LayoutBuilder(
      builder: (context, box) {
        const grabber = 25.0, sideMargins = 48.0;
        // Room the controls need, so short screens shrink the cover, not them.
        const controls = 300.0;
        final art = min(
          box.maxWidth - sideMargins,
          box.maxHeight - grabber - controls,
        ).clamp(120.0, double.infinity).toDouble();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: inset,
              child: Column(
                children: [
                  // Drag down on the cover to close, as Apple Music does.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) > 200) {
                        Navigator.pop(context);
                      }
                    },
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200) player.seekToNext();
                      if (v > 200) player.seekToPrevious();
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Semantics(
                            button: true,
                            label: 'Close player',
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: scheme.onSurface.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        _Artwork(song: song, size: art),
                      ],
                    ),
                  ),
                  // Everything below shares the leftover height evenly, so no gap
                  // grows out of proportion on tall screens.
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [...previous, ?current],
                                ),
                                child: Column(
                                  key: ValueKey(song.uniqueId),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineSmall,
                                    ),
                                    Text(
                                      song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SpringPress(
                              child: IconButton(
                                tooltip: song.favorite
                                    ? 'Remove from favorites'
                                    : 'Add to favorites',
                                onPressed: () =>
                                    app.player.toggleFavorite(song),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  transitionBuilder: (child, a) =>
                                      ScaleTransition(
                                        scale: CurvedAnimation(
                                          parent: a,
                                          curve: expressiveSpring,
                                        ),
                                        child: child,
                                      ),
                                  child: Icon(
                                    song.favorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey(song.favorite),
                                    color: song.favorite
                                        ? scheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            SongMenu(
                              song: song,
                              icon: Icons.more_horiz_rounded,
                            ),
                          ],
                        ),
                        Padding(
                          padding: inset,
                          child: _Progress(song: song),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SpringPress(
                              child: IconButton(
                                tooltip: 'Previous',
                                iconSize: 44,
                                icon: const Icon(Icons.skip_previous_rounded),
                                onPressed: player.seekToPrevious,
                              ),
                            ),
                            const PlayPauseButton(large: true),
                            SpringPress(
                              child: IconButton(
                                tooltip: 'Next',
                                iconSize: 44,
                                icon: const Icon(Icons.skip_next_rounded),
                                onPressed: player.seekToNext,
                              ),
                            ),
                          ],
                        ),
                        const _BottomRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The cover: full size while playing and slightly smaller when paused. Its
/// slot stays the same size, so pausing doesn't move anything else.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.song, required this.size});
  final Song song;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: StreamBuilder<bool>(
      stream: app.player.out.playingStream,
      initialData: app.player.out.playing,
      builder: (context, snap) => AnimatedScale(
        scale: snap.data == true ? 1 : 0.92,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 40,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Hero(
            tag: _heroTag,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              // By song, not cover path: a new cover for the same song swaps in place.
              child: RepaintBoundary(
                key: ValueKey(song.uniqueId),
                child: Cover(song, size: size, radius: 28),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final player = app.player.out;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration ?? Duration(seconds: song.durationSec);
        final position = snap.data ?? Duration.zero;
        final ms = total.inMilliseconds;
        return Column(
          children: [
            StreamBuilder<bool>(
              stream: player.playingStream,
              initialData: player.playing,
              builder: (context, playing) => WavySeek(
                value: ms > 0 ? position.inMilliseconds / ms : 0,
                buffered: ms > 0
                    ? player.bufferedPosition.inMilliseconds / ms
                    : 0,
                playing: playing.data ?? false,
                label: formatDuration(position),
                onSeek: ms > 0
                    ? (v) =>
                          player.seek(Duration(milliseconds: (v * ms).round()))
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(formatDuration(position), style: muted)),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showSongInfo(context, song),
                  child: Semantics(
                    button: true,
                    label: 'Audio quality and song info',
                    child: Container(
                      height: 24,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QualityLabel(song, detailed: true, style: muted),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '-${formatDuration(total - position < Duration.zero ? Duration.zero : total - position)}',
                    textAlign: TextAlign.end,
                    style: muted,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ShuffleButton extends StatelessWidget {
  const ShuffleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final player = app.player.out;
    return StreamBuilder<bool>(
      stream: player.shuffleModeEnabledStream,
      builder: (context, snap) {
        final on = snap.data ?? false;
        return IconButton(
          tooltip: on ? 'Shuffle on' : 'Shuffle off',
          isSelected: on,
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: () async {
            if (!on) await player.shuffle();
            await player.setShuffleModeEnabled(!on);
          },
        );
      },
    );
  }
}

class LoopButton extends StatelessWidget {
  const LoopButton({super.key});

  @override
  Widget build(BuildContext context) {
    final player = app.player.out;
    return StreamBuilder<LoopMode>(
      stream: player.loopModeStream,
      builder: (context, snap) {
        final mode = snap.data ?? LoopMode.off;
        return IconButton(
          tooltip: 'Repeat: ${mode.name}',
          isSelected: mode != LoopMode.off,
          icon: Icon(mode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
          onPressed: () => player.setLoopMode(LoopMode.values[(mode.index + 1) % LoopMode.values.length]),
        );
      },
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        tooltip: 'Lyrics',
        icon: const Icon(Icons.lyrics_outlined),
        onPressed: () {
          final song = app.player.current.value;
          if (song == null) return;
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => LyricsScreen(song: song)),
          );
        },
      ),
      const ShuffleButton(),
      const LoopButton(),
      ValueListenableBuilder(
        valueListenable: app.player.sleepAt,
        builder: (context, sleepAt, _) => IconButton(
          tooltip: sleepAt == null ? 'Sleep timer and speed' : 'Sleep timer on',
          isSelected: sleepAt != null,
          icon: const Icon(Icons.bedtime_outlined),
          selectedIcon: const Icon(Icons.bedtime_rounded),
          onPressed: () => _showSleepAndSpeed(context),
        ),
      ),
      const DeviceButton(),
      IconButton(
        tooltip: 'Queue',
        icon: const Icon(Icons.queue_music_rounded),
        onPressed: () => showQueue(context),
      ),
    ],
  );
}

Future<void> _showSleepAndSpeed(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sleep timer', style: Theme.of(sheet).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: app.player.sleepAt,
            builder: (context, sleepAt, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in const [15, 30, 45, 60, 90])
                  ActionChip(
                    label: Text('$minutes min'),
                    onPressed: () {
                      app.player.setSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(sheet);
                    },
                  ),
                if (sleepAt != null)
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 18),
                    label: Text(
                      'Off (pauses at ${TimeOfDay.fromDateTime(sleepAt).format(context)})',
                    ),
                    onPressed: () {
                      app.player.setSleepTimer(null);
                      Navigator.pop(sheet);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Playback speed', style: Theme.of(sheet).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<double>(
            stream: app.player.out.speedStream,
            initialData: app.player.out.speed,
            builder: (context, snap) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final speed in const [0.75, 1.0, 1.25, 1.5, 2.0])
                  ChoiceChip(
                    label: Text('$speed×'),
                    selected: snap.data == speed,
                    onSelected: (_) => app.player.out.setSpeed(speed),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

Future<void> showQueue(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (sheet) => SizedBox(
    height: MediaQuery.sizeOf(sheet).height * 0.8,
    child: Column(
      children: [
        Text('Up next', style: Theme.of(sheet).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Expanded(child: QueueView()),
      ],
    ),
  ),
);

/// The queue: drag to reorder, swipe away to remove, tap to play.
class QueueView extends StatelessWidget {
  const QueueView({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: app.player.queue,
    builder: (context, queue, _) => ValueListenableBuilder(
      valueListenable: app.player.current,
      builder: (context, current, _) => ReorderableListView.builder(
        itemCount: queue.length,
        onReorder: (from, to) => app.player.moveInQueue(from, to > from ? to - 1 : to),
        itemBuilder: (context, i) {
          final s = queue[i];
          final playing = s.uniqueId == current?.uniqueId;
          return Dismissible(
            key: ValueKey('q${s.uniqueId}'),
            direction: playing ? DismissDirection.none : DismissDirection.endToStart,
            onDismissed: (_) => app.player.removeFromQueue(i),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.remove_circle_outline_rounded),
            ),
            child: ListTile(
              selected: playing,
              leading: Cover(s, size: 48, radius: 8),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => app.player.out.seek(Duration.zero, index: i),
            ),
          );
        },
      ),
    ),
  );
}

class LyricsScreen extends StatelessWidget {
  const LyricsScreen({super.key, required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(song.title, style: Theme.of(context).textTheme.titleLarge)),
    body: LyricsView(song: song),
  );
}

/// A song's lyrics, following along when they have timestamps.
class LyricsView extends StatefulWidget {
  const LyricsView({super.key, required this.song});
  final Song song;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late final _lyrics = app.enricher.lyrics(widget.song);
  final _activeKey = GlobalKey();
  var _lastActive = -1;

  void _follow(int active) {
    if (active == _lastActive) return;
    _lastActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _activeKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.4,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String?>(
      future: _lyrics,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: LoadingIndicatorM3E());
        }
        if (snap.hasError) {
          return const Center(child: Text('Lyrics service is not reachable.'));
        }
        final text = snap.data;
        if (text == null) {
          return const Center(child: Text('No lyrics found.'));
        }
        final lines = parseLrc(text);
        if (lines.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(text, style: theme.textTheme.titleMedium),
          );
        }
        return StreamBuilder<Duration>(
          stream: app.player.out.positionStream,
          builder: (context, pos) {
            final at = pos.data ?? Duration.zero;
            final active = lines.lastIndexWhere((l) => l.time <= at);
            _follow(active);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      key: i == active ? _activeKey : null,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: theme.textTheme.headlineSmall!.copyWith(
                          color: i == active
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        child: Text(lines[i].text),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
