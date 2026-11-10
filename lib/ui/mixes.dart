import 'package:flutter/material.dart';

import '../app.dart';
import '../library/db.dart';
import '../library/mood.dart';
import 'home.dart';
import 'widgets.dart';

/// Lets a song's menu offer "doesn't fit" while it's shown inside a mix.
class MixScope extends InheritedWidget {
  const MixScope({super.key, required this.mix, required this.onReject, required super.child});
  final DailyMix mix;
  final ValueChanged<Song> onReject;

  static MixScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MixScope>();

  @override
  bool updateShouldNotify(MixScope old) => mix != old.mix;
}

/// Up to four different covers in a grid, or one if there aren't enough.
class CoverMosaic extends StatelessWidget {
  const CoverMosaic({super.key, required this.songs, required this.size, this.radius = 8});
  final List<Song> songs;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distinct = <Song>[];
    final seen = <String>{};
    for (final s in songs) {
      if (seen.add(s.album.isNotEmpty ? s.album : s.uniqueId)) distinct.add(s);
      if (distinct.length == 4) break;
    }
    if (distinct.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(radius)),
        child: Icon(Icons.queue_music_rounded, color: scheme.onPrimaryContainer, size: size * 0.5),
      );
    }
    if (distinct.length < 4) return Cover(distinct.first, size: size, radius: radius);
    final half = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [for (final s in distinct) Cover(s, size: half, radius: 0)],
        ),
      ),
    );
  }
}

/// A playlist's art, made from the songs in it and kept up to date.
class PlaylistArt extends StatefulWidget {
  const PlaylistArt({super.key, required this.playlistId, required this.size, this.radius = 8});
  final int playlistId;
  final double size, radius;

  @override
  State<PlaylistArt> createState() => _PlaylistArtState();
}

class _PlaylistArtState extends State<PlaylistArt> {
  late final _songs = app.db.watchPlaylistSongs(widget.playlistId);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Song>>(
        stream: _songs,
        builder: (context, snap) => CoverMosaic(
          songs: snap.data ?? const [],
          size: widget.size,
          radius: widget.radius,
        ),
      );
}

/// A Telegram topic's art, made from the songs in it.
class TopicArt extends StatefulWidget {
  const TopicArt({super.key, required this.topic, required this.size, this.radius = 8});
  final ForumTopic topic;
  final double size, radius;

  @override
  State<TopicArt> createState() => _TopicArtState();
}

class _TopicArtState extends State<TopicArt> {
  late final _songs = app.db.watchTopicSongs(widget.topic.chatId, widget.topic.topicId);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Song>>(
        stream: _songs,
        builder: (context, snap) => CoverMosaic(
          songs: snap.data ?? const [],
          size: widget.size,
          radius: widget.radius,
        ),
      );
}

const _moodIcons = <String, IconData>{
  'happy': Icons.wb_sunny_rounded,
  'sad': Icons.water_drop_rounded,
  'drive': Icons.directions_car_rounded,
  'rain': Icons.umbrella_rounded,
  'chill': Icons.spa_rounded,
  'focus': Icons.center_focus_strong_rounded,
  'party': Icons.celebration_rounded,
  'night': Icons.nights_stay_rounded,
  'love': Icons.favorite_rounded,
  'workout': Icons.fitness_center_rounded,
};

const _moodColors = <String, Color>{
  'happy': Color(0xFFB8860B),
  'sad': Color(0xFF34568B),
  'drive': Color(0xFFB5482A),
  'rain': Color(0xFF3F6B7D),
  'chill': Color(0xFF2F7D6B),
  'focus': Color(0xFF4F5B93),
  'party': Color(0xFFA8326E),
  'night': Color(0xFF3B2F6B),
  'love': Color(0xFFB03A5B),
  'workout': Color(0xFFA33A2A),
};

/// A daily mix on a shelf: its covers washed in the mood's colour, with its name.
class MixCard extends StatelessWidget {
  const MixCard({super.key, required this.mix, required this.size});
  final DailyMix mix;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _moodColors[mix.mood.id] ?? theme.colorScheme.primary;
    return SizedBox(
      width: size + 16,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => pushPage(context, MixScreen(mix: mix)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverMosaic(songs: mix.songs, size: size, radius: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.95)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(_moodIcons[mix.mood.id], color: Colors.white, size: 22),
                            const Spacer(),
                            Text(
                              mix.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mix.songs.take(3).map((s) => s.artist).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A daily mix's songs. Each song's menu can say it doesn't fit, which also
/// teaches tomorrow's mixes.
class MixScreen extends StatefulWidget {
  const MixScreen({super.key, required this.mix});
  final DailyMix mix;

  @override
  State<MixScreen> createState() => _MixScreenState();
}

class _MixScreenState extends State<MixScreen> {
  late var _songs = widget.mix.songs;

  void _reject(Song s) {
    setState(() => _songs = _songs.where((x) => x.uniqueId != s.uniqueId).toList());
    app.db.setMoodVote(s, widget.mix.mood.id, -1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed from ${widget.mix.title}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted) setState(() => _songs = widget.mix.songs.where((x) => x.uniqueId == s.uniqueId || _songs.contains(x)).toList());
            app.db.setMoodVote(s, widget.mix.mood.id, 0);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MixScope(
        mix: widget.mix,
        onReject: _reject,
        child: CollectionScreen(title: widget.mix.title, songs: _songs),
      );
}
