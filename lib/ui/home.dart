import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import '../app.dart';
import '../library/audio_info.dart';
import '../library/auto_filer.dart';
import '../library/db.dart';
import '../library/throttle.dart';
import 'chat_review.dart';
import 'cover_colors.dart';
import 'desktop.dart';
import 'devices.dart';
import 'discover.dart';
import 'glass/glass_nav_bar.dart';
import 'library_status.dart';
import 'player_screen.dart';
import 'playlists.dart';
import 'profile_page.dart';
import 'settings.dart';
import 'tasks_screen.dart';
import 'uploads.dart';
import 'widgets.dart';

const _libraryTabs = ['Songs', 'Albums', 'Artists', 'Playlists'];

void pushPage(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

/// Opens an album, artist or genre.
void openCollection(BuildContext context, String title, List<Song> songs, {String? subtitle}) =>
    pushPage(context, CollectionScreen(title: title, subtitle: subtitle, songs: songs));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Bumped when the app comes back, so the status bar is built fresh. Android reopening a
  // running app can leave one layout pass broken, which froze the status bar.
  var _epoch = 0;

  StreamSubscription<String>? _openSub;

  /// Another of the owner's devices wants to sign in through this one: only on a tap.
  Future<void> _askQr() async {
    final req = app.qrRequests.value;
    if (req == null || !mounted) return;
    app.qrRequests.value = null;
    final ok = await confirm(
      context,
      'Sign in ${req.device}?',
      'It will get its own session of your Telegram account, used only to delete old posts. Allow only if you just asked for this on that device.',
      'Allow',
    );
    if (!ok) return;
    try {
      await app.userSession.approveQr(req.link);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not approve: $e')));
    }
  }

  Future<void> _openFromNotification() async => _route(await app.background.takeOpen());

  /// `tasks` opens Tasks; `copy:<chat>:<title>` opens that chat's review.
  void _route(String? open) {
    if (open == null || open.isEmpty || !mounted) return;
    if (open == 'tasks') {
      Navigator.of(context).popUntil((r) => r.isFirst);
      pushPage(context, const TasksScreen());
      return;
    }
    if (!open.startsWith('copy:')) return;
    final parts = open.split(':');
    final id = int.tryParse(parts[1]);
    if (id == null) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ChatReviewScreen(chatId: id, title: parts.sublist(2).join(':'))),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _epoch++);
      unawaited(_openFromNotification());
    }
  }

  final _songs = throttled(
    app.db.watchSongs(),
    const Duration(seconds: 2),
  ).asBroadcastStream();
  final _searchFocus = FocusNode();

  /// Home is 0, Search 1, Library 2.
  var _section = 0;
  var _libraryTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openSub = app.background.opened.stream.listen(_route);
    app.qrRequests.addListener(_askQr);
    unawaited(_openFromNotification()); // A tap that started the app.
    app.player.error.addListener(_showPlayerError);
    app.searchRequests.addListener(_openSearch);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openSub?.cancel();
    app.qrRequests.removeListener(_askQr);
    app.player.error.removeListener(_showPlayerError);
    app.searchRequests.removeListener(_openSearch);
    _searchFocus.dispose();
    super.dispose();
  }

  void _showPlayerError() {
    final e = app.player.error.value;
    if (e == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
    app.player.error.value = null;
  }

  void _openSearch() => _select(1);

  void _select(int section, [int? library]) {
    setState(() {
      _section = section;
      if (library != null) _libraryTab = library;
    });
    if (section == 1) _searchFocus.requestFocus();
  }

  String get _title {
    if (_section == 1) return 'Search';
    if (_section == 3) return 'Profile';
    if (_section == 2) return isDesktop(context) ? _libraryTabs[_libraryTab] : 'Your library';
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
  }

  PreferredSizeWidget _appBar() => AppBar(
    toolbarHeight: 64,
    titleSpacing: 16,
    title: Text(_title, key: ValueKey(_title)),
    actions: [
      // On a phone with nothing playing, this is the way to pick another device.
      if (!isDesktop(context)) const DeviceButton(),
      // Uploads and settings live on the Profile page only.
      if (_section == 3) ...[
      IconButton(
        tooltip: 'Uploads',
        icon: const Icon(Icons.upload_rounded),
        onPressed: () => pushPage(context, const UploadsScreen()),
      ),
      IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_rounded),
        onPressed: () => pushPage(context, const SettingsScreen()),
      ),
      ],
      const SizedBox(width: 4),
    ],
  );

  Widget _pages(ThemeData theme) => Column(
    children: [
      StatusBanner(key: ValueKey(_epoch)),
      Expanded(
        child: StreamBuilder<List<Song>>(
          stream: _songs,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: LoadingIndicatorM3E());
            final songs = snap.data!;
            // Lists leave room at the end for the mini player and the bar.
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(context).copyWith(
                  bottom: MediaQuery.paddingOf(context).bottom + (isDesktop(context) ? 8 : 84),
                ),
              ),
              // Pages stay alive so each keeps its scroll position.
              child: IndexedStack(
                index: _section,
                children: [
                  HomePage(songs: songs),
                  SearchPage(songs: songs, focus: _searchFocus),
                  _LibraryPage(
                    songs: songs,
                    tab: _libraryTab,
                    onTab: (i) => setState(() => _libraryTab = i),
                  ),
                  ProfilePage(songs: songs, openLibrary: (tab) => _select(2, tab)),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );

  /// Back leaves a tab for Home before it leaves the app. With canPop false Android
  /// shows its predictive animation only once Home is reached, as it should.
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _section == 0,
        onPopInvokedWithResult: (popped, _) {
          if (popped) return;
          FocusManager.instance.primaryFocus?.unfocus();
          if (_section == 2 && _libraryTab != 0 && !isDesktop(context)) {
            setState(() => _libraryTab = 0);
          } else {
            _select(0);
          }
        },
        child: _shell(context),
      );

  Widget _shell(BuildContext context) {
    final theme = Theme.of(context);
    if (isDesktop(context)) {
      return DesktopShell(
        section: _section,
        library: _libraryTab,
        onSelect: _select,
        page: Scaffold(appBar: _appBar(), body: _pages(theme)),
      );
    }
    return ValueListenableBuilder(
      valueListenable: app.ui.floatingNav,
      builder: (context, floating, _) => Scaffold(
        // The bar is glass either way, so the list scrolls underneath it.
        extendBody: true,
        appBar: _appBar(),
        body: Stack(
          children: [
            // Filled, so the page column gets tight constraints from the first frame.
            Positioned.fill(child: _pages(theme)),
            Builder(
              builder: (context) => Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                  child: const MiniPlayer(),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _HomeNav(
          floating: floating,
          selected: _section,
          onSelected: _select,
        ),
      ),
    );
  }
}

/// Everything in the library. A phone switches with chips; a PC uses the sidebar.
class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.songs, required this.tab, required this.onTab});
  final List<Song> songs;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!isDesktop(context))
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            children: [
              for (final (i, name) in _libraryTabs.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: i == tab,
                    showCheckmark: false,
                    onSelected: (_) => onTab(i),
                  ),
                ),
            ],
          ),
        ),
      Expanded(
        child: IndexedStack(
          index: tab,
          children: [
            SongList(songs: songs, sortable: true),
            _AlbumGrid(songs: songs),
            _ArtistList(songs: songs),
            PlaylistsTab(songs: songs),
          ],
        ),
      ),
    ],
  );
}

const _navEntries = [
  NavEntry(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
  NavEntry(icon: Icons.search_rounded, selectedIcon: Icons.manage_search_rounded, label: 'Search'),
  NavEntry(icon: Icons.library_music_outlined, selectedIcon: Icons.library_music_rounded, label: 'Library'),
  NavEntry(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
];

/// The tab bar: floating with rounded corners, or the regular full-width bar.
class _HomeNav extends StatelessWidget {
  const _HomeNav({
    required this.floating,
    required this.selected,
    required this.onSelected,
  });
  final bool floating;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassNavBar(items: _navEntries, selected: selected, onSelected: onSelected, floating: floating);
  }
}

/// Play and shuffle above a list, with how much is in it.
class PlayRow extends StatelessWidget {
  const PlayRow({super.key, required this.songs});
  final List<Song> songs;

  String _length() {
    final seconds = songs.fold<int>(0, (sum, s) => sum + s.durationSec);
    final hours = seconds ~/ 3600, minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '$hours hr $minutes min' : '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          SpringPress(
            child: IconButton.filled(
              tooltip: 'Play',
              iconSize: 32,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => app.player.play(songs, 0),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Shuffle',
            iconSize: 26,
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () => app.player.playShuffled(songs),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${songs.length == 1 ? '1 song' : '${songs.length} songs'} · ${_length()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// A fast song list: fixed row heights and a draggable scrollbar for big libraries.
class SongList extends StatefulWidget {
  const SongList({
    super.key,
    required this.songs,
    this.header,
    this.playlistId,
    this.sortable = false,
  });
  final List<Song> songs;

  /// Shows the sort menu. Off for playlists, whose order is their own.
  final bool sortable;
  final Widget? header;
  final int? playlistId;

  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  /// Rows only animate in on first show, not each time one scrolls into view.
  var _entering = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _entering = false);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    // Leaving a list leaves picking, so other lists don't show it.
    if (selection.value.isNotEmpty) selection.value = const {};
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final songs = widget.sortable
        ? sortSongs(oneVersionEach(widget.songs, app.mainChat.value), _sort.value, _reverse.value)
        : widget.songs;
    if (songs.isEmpty && widget.header == null) {
      return const Center(
        child: Text('No songs yet. They appear here as they sync.'),
      );
    }
    return ValueListenableBuilder(
      valueListenable: selection,
      // Back while picking just stops picking.
      builder: (context, picked, child) => PopScope(
        canPop: picked.isEmpty,
        onPopInvokedWithResult: (popped, _) {
          if (!popped) selection.value = const {};
        },
        child: child!,
      ),
      child: Column(
      children: [
        SelectionBar(songs: songs),
        Expanded(
          child: Scrollbar(
      controller: _scroll,
      interactive: true,
      thickness: 8,
      radius: const Radius.circular(4),
      child: CustomScrollView(
        controller: _scroll,
        // Decodes covers slightly ahead of the screen, so they don't pop in.
        cacheExtent: 600,
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          if (songs.isNotEmpty)
            SliverToBoxAdapter(child: PlayRow(songs: songs)),
          if (songs.isNotEmpty && widget.sortable)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<SongSort>(
                        tooltip: 'Sort',
                        initialValue: _sort.value,
                        onSelected: (v) => setState(() => _sort.value = v),
                        itemBuilder: (_) => [
                          for (final v in SongSort.values) PopupMenuItem(value: v, child: Text(v.label)),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 20),
                              const SizedBox(width: 6),
                              Text(_sort.value.label),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _reverse.value ? 'Reversed' : 'Reverse',
                        icon: Icon(_reverse.value ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 20),
                        onPressed: () => setState(() => _reverse.value = !_reverse.value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (songs.isNotEmpty && isDesktop(context))
            const SliverToBoxAdapter(child: DesktopSongHeader()),
          SliverFixedExtentList(
            itemExtent: isDesktop(context) ? 56 : songTileExtent,
            delegate: SliverChildBuilderDelegate(childCount: songs.length, (
              context,
              i,
            ) {
              final Widget tile = isDesktop(context)
                  ? DesktopSongRow(
                      key: ValueKey(songs[i].uniqueId),
                      songs: songs,
                      index: i,
                      playlistId: widget.playlistId,
                    )
                  : SongTile(
                      key: ValueKey(songs[i].uniqueId),
                      songs: songs,
                      index: i,
                      playlistId: widget.playlistId,
                    );
              return _entering && i < 10
                  ? Entrance(index: i, child: tile)
                  : tile;
            }),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ),
        ],
      ),
    ),
        ),
      ],
    ),
    );
  }
}

Map<String, List<Song>> _groupBy(
  List<Song> songs,
  String Function(Song) keyOf,
) {
  final groups = <String, List<Song>>{};
  for (final s in songs) {
    final key = keyOf(s);
    if (key.isNotEmpty) (groups[key] ??= []).add(s);
  }
  return groups;
}

List<String> _sortedNames(Map<String, List<Song>> groups) =>
    groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final groups = _groupBy(songs, (s) => s.album);
    final names = _sortedNames(groups);
    if (names.isEmpty) {
      return const Center(child: Text('Albums appear as song info is found.'));
    }
    return LayoutBuilder(
      builder: (context, box) {
        const pad = 8.0, cardInset = 16.0;
        final cols = max(2, ((box.maxWidth - pad * 2) / 176).floor());
        final card = (box.maxWidth - pad * 2) / cols;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, MediaQuery.paddingOf(context).bottom + 16),
          cacheExtent: 600,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: card + 50,
          ),
          itemCount: names.length,
          itemBuilder: (context, i) {
            final list = groups[names[i]]!;
            return MediaCard(
              song: list.first,
              title: names[i],
              subtitle: list.first.artist,
              size: card - cardInset,
              onTap: () => openCollection(context, names[i], list, subtitle: list.first.artist),
            );
          },
        );
      },
    );
  }
}

class _ArtistList extends StatelessWidget {
  const _ArtistList({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final groups = _groupBy(songs, (s) => s.artist);
    final names = _sortedNames(groups);
    if (names.isEmpty) return const Center(child: Text('Nothing here yet.'));
    return ListView.builder(
      itemExtent: 76,
      itemCount: names.length,
      itemBuilder: (context, i) {
        final list = groups[names[i]]!;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: ClipPath(
            clipper: const CookieClipper(),
            child: Cover(list.first, size: 56, radius: 0),
          ),
          title: Text(names[i], maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(list.length == 1 ? '1 song' : '${list.length} songs'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CollectionScreen(title: names[i], songs: list),
            ),
          ),
        );
      },
    );
  }
}

/// A big heading washed in its cover's colours, for any list of songs.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({super.key, required this.title, this.subtitle, required this.songs, this.art});
  final String title;
  final String? subtitle;
  final List<Song> songs;

  /// Replaces the first song's cover, such as a playlist's own art.
  final Widget Function(double size)? art;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = isDesktop(context);
    final top = MediaQuery.paddingOf(context).top;
    final cover = songs.isEmpty ? null : songs.first;
    final text = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: wide ? theme.textTheme.displaySmall : theme.textTheme.headlineSmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
    return CoverColors(
      path: cover?.coverPath,
      brightness: theme.brightness,
      builder: (context, scheme) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme?.primaryContainer ?? theme.colorScheme.surfaceContainerHigh,
              theme.scaffoldBackgroundColor.withValues(alpha: 0),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, top + 8, wide ? 24 : 16, 20),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (art != null || cover != null) ...[
                      art?.call(184) ?? Cover(cover, size: 184, radius: 12),
                      const SizedBox(width: 24),
                    ],
                    Expanded(child: text),
                  ],
                )
              : Column(
                  children: [
                    if (art != null || cover != null) ...[
                      art?.call(200) ?? Cover(cover, size: 200, radius: 14),
                      const SizedBox(height: 16),
                    ],
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// An album, artist or smart list, with a large cover heading.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.songs,
  });
  final String title;
  final String? subtitle;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(backgroundColor: Colors.transparent),
    body: Column(
      children: [
        Expanded(
          // The list was copied when this opened; follow the library so deleted songs leave it.
          child: ValueListenableBuilder(
            valueListenable: app.liveSongs,
            builder: (context, live, _) {
              final current = [for (final s in songs) ?live[s.uniqueId]];
              return SongList(
                songs: current,
                header: CollectionHeader(title: title, subtitle: subtitle, songs: current),
              );
            },
          ),
        ),
        const SafeArea(top: false, child: MiniPlayer()),
      ],
    ),
  );
}

/// Mini player in the current cover's colours. Tap or swipe up to open; swipe
/// sideways to skip.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) return const SizedBox.shrink();
    final player = app.player.out;
    return ValueListenableBuilder(
      valueListenable: app.player.current,
      builder: (context, song, _) => AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: song == null
            ? const SizedBox(width: double.infinity)
            : CoverColors(
                path: song.coverPath,
                brightness: Brightness.dark,
                builder: (context, cover) {
                  final base = Theme.of(context);
                  final tinted = cover == null ? base : coverDarkTheme(cover);
                  final background = cover == null
                      ? base.colorScheme.secondaryContainer
                      : Color.lerp(cover.primaryContainer, Colors.black, 0.35)!;
                  return Theme(
                    data: tinted,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          type: MaterialType.transparency,
                          child: GestureDetector(
                            onVerticalDragEnd: (d) {
                              if ((d.primaryVelocity ?? 0) < -200) openPlayer(context);
                            },
                            onHorizontalDragEnd: (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v < -200) player.seekToNext();
                              if (v > 200) player.seekToPrevious();
                            },
                            child: InkWell(
                              onTap: () => openPlayer(context),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                                    child: Row(
                                      children: [
                                        Hero(
                                          tag: 'now-playing-cover',
                                          // Kept apart from the progress bar, which redraws often.
                                          child: RepaintBoundary(child: Cover(song, size: 44, radius: 8)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 220),
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
                                                  style: tinted.textTheme.titleSmall,
                                                ),
                                                Text(
                                                  song.artist,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: tinted.textTheme.bodySmall,
                                                ),
                                                const PlayingOnLabel(),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const DeviceButton(),
                                        IconButton(
                                          tooltip: 'Previous',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.skip_previous_rounded),
                                          onPressed: app.player.out.seekToPrevious,
                                        ),
                                        const PlayPauseButton(),
                                        IconButton(
                                          tooltip: 'Next',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.skip_next_rounded),
                                          onPressed: app.player.out.seekToNext,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const _MiniProgress(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context) {
    final player = app.player.out;
    return RepaintBoundary(
      child: StreamBuilder<Duration>(
        stream: player.positionStream,
        builder: (context, snap) {
          final total = player.duration?.inMilliseconds ?? 0;
          return LinearProgressIndicator(
            minHeight: 2,
            value: total > 0
                ? ((snap.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0)
                : 0,
            backgroundColor: Colors.transparent,
          );
        },
      ),
    );
  }
}

/// Ways to sort the library's song list. Each puts the most useful end first.
enum SongSort {
  added('Recently added'),
  title('Title'),
  artist('Artist'),
  album('Album'),
  quality('Quality'),
  size('Size'),
  duration('Length'),
  year('Year'),
  plays('Most played');

  const SongSort(this.label);
  final String label;
}

// Remembered on this device, so lists open the way they were left.
final _sort = ValueNotifier(SongSort.added);
final _reverse = ValueNotifier(false);

Future<void> loadSortPrefs() async {
  final name = await app.db.pref('sort_songs');
  _sort.value = SongSort.values.where((s) => s.name == name).firstOrNull ?? SongSort.added;
  _reverse.value = await app.db.pref('sort_reverse') == 'true';
  _sort.addListener(() => app.db.setPref('sort_songs', _sort.value.name));
  _reverse.addListener(() => app.db.setPref('sort_reverse', '${_reverse.value}'));
  await loadPlaylistSort();
}

List<Song> sortSongs(List<Song> songs, SongSort by, bool reverse) {
  int text(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  final int Function(Song, Song) cmp = switch (by) {
    SongSort.added => (a, b) => b.date.compareTo(a.date),
    SongSort.title => (a, b) => text(a.title, b.title),
    SongSort.artist => (a, b) {
        final c = text(a.artist, b.artist);
        return c != 0 ? c : text(a.album, b.album);
      },
    SongSort.album => (a, b) {
        final c = text(a.album, b.album);
        return c != 0 ? c : text(a.title, b.title);
      },
    SongSort.quality => compareQuality,
    SongSort.size => (a, b) => b.size.compareTo(a.size),
    SongSort.duration => (a, b) => b.durationSec.compareTo(a.durationSec),
    SongSort.year => (a, b) => (b.year ?? 0).compareTo(a.year ?? 0),
    SongSort.plays => (a, b) => b.plays.compareTo(a.plays),
  };
  final sorted = [...songs]..sort(cmp);
  return reverse ? sorted.reversed.toList() : sorted;
}
