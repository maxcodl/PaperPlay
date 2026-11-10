import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../library/db.dart' as db;
import '../library/db.dart' show Playlist, Song;
import '../library/home_mix.dart';
import '../library/mood.dart';
import '../library/neighbours.dart';
import '../library/taste.dart';
import 'desktop.dart';
import 'home.dart';
import 'mixes.dart';
import 'playlists.dart';
import 'widgets.dart';

/// A cover with a title beneath it, for shelves and grids.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.song,
    required this.title,
    required this.subtitle,
    required this.size,
    required this.onTap,
    this.circle = false,
  });

  final Song song;
  final String title;
  final String? subtitle;
  final double size;
  final VoidCallback onTap;

  /// Round, for artists.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size + 16,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Cover(song, size: size, radius: circle ? size / 2 : 10),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: circle ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.titleSmall,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: circle ? TextAlign.center : TextAlign.start,
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

/// A titled row that scrolls sideways. A PC gets arrows, since a mouse wheel
/// only scrolls up and down.
class Shelf extends StatefulWidget {
  const Shelf({super.key, required this.title, this.subtitle, required this.height, required this.children});
  final String title;
  final String? subtitle;
  final double height;
  final List<Widget> children;

  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _by(double sign) {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + sign * p.viewportDimension * 0.8).clamp(0.0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
                  if (isDesktop(context)) ...[
                    IconButton(
                      tooltip: 'Scroll back',
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _by(-1),
                    ),
                    IconButton(
                      tooltip: 'Scroll forward',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _by(1),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            SizedBox(
              height: widget.height,
              child: ListView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: widget.children,
              ),
            ),
          ],
        ),
      );
}

const _cardSize = 136.0, _shelfHeight = _cardSize + 66;

/// Songs that play from their position in [songs].
Shelf songShelf(String title, List<Song> planned) {
  // The plan keeps rows from moving; what they show should still be current.
  final songs = [for (final s in planned) app.fresh(s)];
  return Shelf(
      title: title,
      height: _shelfHeight,
      children: [
        for (final (i, s) in songs.indexed)
          MediaCard(
            key: ValueKey(s.uniqueId),
            song: s,
            title: s.title,
            subtitle: s.artist,
            size: _cardSize,
            onTap: () => app.player.play(songs, i),
          ),
      ],
    );
}

Map<String, List<Song>> _group(Iterable<Song> songs, String? Function(Song) keyOf) {
  final groups = <String, List<Song>>{};
  for (final s in songs) {
    final key = keyOf(s);
    if (key != null && key.isNotEmpty) (groups[key] ??= []).add(s);
  }
  return groups;
}

Shelf albumShelf(BuildContext context, String title, Map<String, List<Song>> albums) => Shelf(
      title: title,
      height: _shelfHeight,
      children: [
        for (final e in albums.entries)
          MediaCard(
            key: ValueKey(e.key),
            song: e.value.first,
            title: e.key,
            subtitle: e.value.first.artist,
            size: _cardSize,
            onTap: () => openCollection(context, e.key, e.value, subtitle: e.value.first.artist),
          ),
      ],
    );

Shelf artistShelf(BuildContext context, String title, Map<String, List<Song>> artists) => Shelf(
      title: title,
      height: _shelfHeight,
      children: [
        for (final e in artists.entries)
          MediaCard(
            key: ValueKey(e.key),
            song: e.value.first,
            title: e.key,
            subtitle: e.value.length == 1 ? '1 song' : '${e.value.length} songs',
            size: _cardSize,
            circle: true,
            onTap: () => openCollection(context, e.key, e.value),
          ),
      ],
    );

/// What to listen to next. Nothing repeats on the page, and it changes daily
/// (see [buildHomeMix]).
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.songs});
  final List<Song> songs;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final _recent = app.db.watchRecent(limit: 30);
  final _favorites = app.db.watchFavorites();
  final _playlists = app.db.watchPlaylists();

  final _votes = app.db.watchMoodVotes();
  final _scanned = app.db.watchMoodScanned();

  HomeMix? _mix;
  String? _mixKey;
  List<Song> _suggested = const [];
  String? _suggestKey;
  Map<String, List<String>>? _neighbours;
  String? _neighboursKey;

  /// "Suggested for you": songs close to what was played or liked lately. The neighbour table is
  /// built off the UI thread, and only when the library or its playlists change.
  Future<void> _planSuggestions(List<Song> songs, List<Song> recent, List<Song> liked) async {
    final now = DateTime.now();
    final key = '${now.year}-${now.month}-${now.day}:${songs.length}:${recent.length}:${liked.length}';
    if (key == _suggestKey) return;
    _suggestKey = key;
    final tableKey = '${songs.length}';
    if (_neighbours == null || _neighboursKey != tableKey) {
      final byKey = {for (final s in songs) (s.chatId, s.messageId): s.uniqueId};
      final lists = <int, List<String>>{};
      for (final r in await app.db.select(app.db.playlistSongs).get()) {
        final id = byKey[(r.chatId, r.messageId)];
        if (id != null) (lists[r.playlistId] ??= []).add(id);
      }
      final topics = <(int, int), List<String>>{};
      for (final s in songs) {
        final t = s.topicId;
        if (t != null && t != generalTopicId) (topics[(s.chatId, t)] ??= []).add(s.uniqueId);
      }
      _neighbours = await compute(_neighboursOf, (songs, [...lists.values, ...topics.values]));
      _neighboursKey = tableKey;
    }
    final byId = {for (final s in songs) s.uniqueId: s};
    // The newest few plays and likes, so the shelf follows the mood without rebuilding the table.
    final seeds = [...recent.take(6), ...liked.take(6)];
    final got = suggestFrom(seeds, _neighbours!, byId, exclude: {for (final s in recent) s.uniqueId});
    if (mounted && key == _suggestKey) setState(() => _suggested = got);
  }
  List<DailyMix> _daily = const [];
  String? _dailyKey;

  /// Planned off the UI thread, since it reads every song's lyrics. Rows only
  /// change when the day, weather, verdicts or a good chunk of the library does.
  Future<void> _planDaily(List<Song> songs, List<db.MoodVote> votes, int scanned) async {
    final now = DateTime.now();
    final weather = app.weather.kind.value;
    final taste = app.taste.value;
    final key = '${now.year}-${now.month}-${now.day}:${songs.length}:${votes.length}:${scanned ~/ 50}:$weather:${taste.at}';
    if (key == _dailyKey) return;
    _dailyKey = key;
    final lists = await app.tasteLists();
    final byId = {for (final s in songs) (s.chatId, s.messageId): s};
    final verdicts = [
      for (final v in votes)
        if (v.vote != 0 && byId[(v.chatId, v.messageId)] != null)
          MoodVerdict(byId[(v.chatId, v.messageId)]!.uniqueId, byId[(v.chatId, v.messageId)]!.artist, v.mood, v.vote),
    ];
    final mixes = await compute(_buildMixes, (songs, now, verdicts, weather, lists, taste));
    if (mounted && key == _dailyKey) setState(() => _daily = mixes);
  }

  @override
  bool get wantKeepAlive => true;

  /// Rebuilt only when the library or the day changes. Replanning on every song
  /// played would make rows jump around under the mouse.
  HomeMix _mixFor(List<Song> songs, List<Song> recent, List<Song> favorites, int reservedTiles) {
    final now = DateTime.now();
    final key = '${now.year}-${now.month}-${now.day}:${songs.length}:${favorites.length}:$reservedTiles';
    if (key != _mixKey || _mix == null) {
      _mixKey = key;
      _mix = buildHomeMix(
        songs: songs,
        recent: recent,
        favorites: favorites,
        day: now,
        tileCount: 6 - reservedTiles,
      );
    }
    return _mix!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final songs = widget.songs;
    if (songs.isEmpty) {
      return const Center(child: Text('No songs yet. They appear here as they sync.'));
    }
    return StreamBuilder<List<Song>>(
      stream: _recent,
      builder: (context, recent) => StreamBuilder<List<Song>>(
        stream: _favorites,
        builder: (context, favorites) => StreamBuilder<List<Playlist>>(
          stream: _playlists,
          builder: (context, playlists) {
            // Waits for the first answers, so the plan isn't made without them.
            if (!recent.hasData || !favorites.hasData || !playlists.hasData) {
              return const SizedBox.shrink();
            }
            final liked = favorites.data!;
            final lists = playlists.data!.take(3).toList();
            final mix = _mixFor(songs, recent.data!, liked, lists.length + (liked.isEmpty ? 0 : 1));
            return StreamBuilder<List<db.MoodVote>>(
              stream: _votes,
              builder: (context, votes) => StreamBuilder<int>(
                stream: _scanned,
                builder: (context, scanned) => ListenableBuilder(
                  listenable: Listenable.merge([app.weather.kind, app.taste]),
                  builder: (context, _) {
                    if (votes.hasData && scanned.hasData) {
                      unawaited(_planDaily(songs, votes.data!, scanned.data!));
                    }
                    unawaited(_planSuggestions(songs, recent.data!, liked));
                    final showMixes = app.taste.value.showMixes;
                    final learned = scanned.data ?? 0;
                    return ListView(
                      padding: EdgeInsets.only(top: 4, bottom: MediaQuery.paddingOf(context).bottom + 16),
                      children: [
                        _QuickGrid(favorites: liked, playlists: lists, tiles: mix.tiles),
                        if (showMixes && _daily.isNotEmpty)
                          Shelf(
                            title: 'Your daily mixes',
                            subtitle: learned < songs.length
                                ? 'Still learning your music: $learned of ${songs.length} songs'
                                : null,
                            height: _shelfHeight + 16,
                            children: [
                              for (final m in _daily) MixCard(key: ValueKey(m.mood.id), mix: m, size: _cardSize),
                            ],
                          )
                        else if (showMixes && learned < songs.length)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: Text(
                              'Daily mixes appear as Paper Play learns your music: $learned of ${songs.length} songs.',
                            ),
                          ),
                        if (playlists.data!.isNotEmpty)
                          Shelf(
                            title: 'Your playlists',
                            height: _shelfHeight,
                            children: [
                              for (final p in playlists.data!)
                                _PlaylistCard(key: ValueKey(p.id), playlist: p, size: _cardSize),
                            ],
                          ),
                        if (_suggested.length >= 4) songShelf('Suggested for you', _suggested),
                        for (final shelf in mix.shelves) _shelf(context, shelf),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _shelf(BuildContext context, MixShelf shelf) => switch (shelf.kind) {
        ShelfKind.songs => songShelf(shelf.title, shelf.songs),
        ShelfKind.albums || ShelfKind.artists => Shelf(
            title: shelf.title,
            height: _shelfHeight,
            children: [
              for (final g in shelf.groups)
                MediaCard(
                  key: ValueKey(g.name),
                  song: g.cover,
                  title: g.name,
                  subtitle: shelf.kind == ShelfKind.albums
                      ? g.cover.artist
                      : g.songs.length == 1
                          ? '1 song'
                          : '${g.songs.length} songs',
                  size: _cardSize,
                  circle: shelf.kind == ShelfKind.artists,
                  onTap: () => openCollection(
                    context,
                    g.name,
                    g.songs,
                    subtitle: shelf.kind == ShelfKind.albums ? g.cover.artist : null,
                  ),
                ),
            ],
          ),
      };
}

Map<String, List<String>> _neighboursOf((List<Song>, List<List<String>>) input) => buildNeighbours(input.$1, input.$2);

List<DailyMix> _buildMixes((List<Song>, DateTime, List<MoodVerdict>, WeatherKind?, List<TasteList>, TasteSettings) input) =>
    buildDailyMixes(
      songs: input.$1,
      now: input.$2,
      votes: input.$3,
      weather: input.$4,
      lists: input.$5,
      options: input.$6,
    );

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({super.key, required this.playlist, required this.size});
  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size + 16,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => pushPage(context, PlaylistScreen(playlist: playlist)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlaylistArt(playlistId: playlist.id, size: size, radius: 10),
                  const SizedBox(height: 8),
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// A compact grid of the owner's own collections and generated mixes.
class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.favorites, required this.playlists, required this.tiles});
  final List<Song> favorites;
  final List<Playlist> playlists;
  final List<MixTile> tiles;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (favorites.isNotEmpty)
        _QuickTile(
          leading: favorites.any((s) => s.coverPath != null)
              ? CoverMosaic(songs: favorites, size: 56, radius: 0)
              : const Icon(Icons.favorite_rounded),
          title: 'Favorites',
          onTap: () => pushPage(context, smartList('Favorites', app.db.watchFavorites())),
        ),
      for (final p in playlists)
        _QuickTile(
          leading: PlaylistArt(playlistId: p.id, size: 56, radius: 0),
          title: p.name,
          onTap: () => pushPage(context, PlaylistScreen(playlist: p)),
        ),
      for (final t in tiles)
        _QuickTile(
          cover: t.cover,
          title: t.title,
          onTap: () => openCollection(context, t.title, t.songs),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 720 ? 3 : 2;
        const gap = 8.0;
        final width = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final t in items) SizedBox(width: width, child: t)],
          ),
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({this.cover, this.leading, required this.title, required this.onTap});
  final Song? cover;
  final Widget? leading;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (cover != null)
                Cover(cover, size: 56, radius: 0)
              else
                Container(
                  width: 56,
                  height: 56,
                  color: scheme.primaryContainer,
                  child: IconTheme(data: IconThemeData(color: scheme.onPrimaryContainer), child: leading!),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searches songs, albums and artists. With nothing typed, it browses by genre.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.songs, required this.focus});
  final List<Song> songs;
  final FocusNode focus;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with AutomaticKeepAliveClientMixin {
  final _field = TextEditingController();
  var _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <Song>[]
        : widget.songs
            .where(
              (s) =>
                  s.title.toLowerCase().contains(q) ||
                  s.artist.toLowerCase().contains(q) ||
                  s.album.toLowerCase().contains(q),
            )
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _field,
            focusNode: widget.focus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Songs, artists or albums',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _field.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: q.isEmpty
              ? _GenreGrid(songs: widget.songs)
              : results.isEmpty
                  ? Center(child: Text('Nothing matches "${_query.trim()}".'))
                  : SongList(
                      key: ValueKey(q),
                      songs: results,
                      header: _ResultShelves(query: q, results: results),
                    ),
        ),
      ],
    );
  }
}

/// Albums and artists among the results, above the matching songs.
class _ResultShelves extends StatelessWidget {
  const _ResultShelves({required this.query, required this.results});
  final String query;
  final List<Song> results;

  @override
  Widget build(BuildContext context) {
    final albums = _group(results.where((s) => s.album.toLowerCase().contains(query)), (s) => s.album);
    final artists = _group(results.where((s) => s.artist.toLowerCase().contains(query)), (s) => s.artist);
    return Column(
      children: [
        if (artists.isNotEmpty) artistShelf(context, 'Artists', Map.fromEntries(artists.entries.take(12))),
        if (albums.isNotEmpty) albumShelf(context, 'Albums', Map.fromEntries(albums.entries.take(12))),
      ],
    );
  }
}

class _GenreGrid extends StatelessWidget {
  const _GenreGrid({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final genres = _group(songs, (s) => s.genre).entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (genres.isEmpty) {
      return const Center(child: Text('Genres appear here as song info is found.'));
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / 200).floor().clamp(2, 6);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.9,
          ),
          itemCount: genres.length,
          itemBuilder: (context, i) {
            final g = genres[i];
            // Stable per genre, dark enough for white text in either theme.
            final hue = (g.key.hashCode % 360).abs().toDouble();
            return Material(
              color: HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor(),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openCollection(context, g.key, g.value),
                child: Stack(
                  children: [
                    // A cover from the genre, tilted into the corner.
                    if (g.value.where((s) => s.coverPath != null).firstOrNull case final art?)
                      Positioned(
                        right: -12,
                        bottom: -8,
                        child: Transform.rotate(
                          angle: 0.42,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: Cover(art, size: 64, radius: 6),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 60, 14),
                      child: Text(
                        g.key,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
