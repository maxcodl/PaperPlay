import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'export_list_screen.dart';

import '../app.dart';
import '../library/db.dart';
import '../library/playlist_import.dart';
import '../library/taste.dart';
import 'home.dart';
import 'mixes.dart';
import 'widgets.dart';

/// A topic's name here: the owner's, if they renamed it.
String topicName(ForumTopic t) =>
    app.taste.value.topicNames[TasteSettings.topicKey(t.chatId, t.topicId)] ?? t.name;

/// A page for a list that updates itself, such as Favorites.
Widget smartList(String title, Stream<List<Song>> stream) => StreamBuilder<List<Song>>(
      stream: stream,
      builder: (context, snap) => CollectionScreen(title: title, songs: snap.data ?? const []),
    );

/// Imports the playlist at [link] and reports how it went.
Future<void> runImport(BuildContext context, String link) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Reading playlist…')));
  final client = http.Client();
  try {
    final r = await importPlaylist(app.db, link, client, official: app.spotify.fetchPlaylist);
    final waiting = r.missing == 0 ? '' : ', ${r.missing} not in your library yet';
    final more = r.limited
        ? '. Spotify\'s public page stops at about 100 tracks: connect your account in Settings to get them all.'
        : '';
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${r.name}: ${r.matched} matched$waiting$more'),
        duration: Duration(seconds: r.limited ? 10 : 4),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(e is ImportError ? e.message : 'Import failed: $e')));
  } finally {
    client.close();
  }
}

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key, required this.songs});

  /// Keeps smart lists fresh when the library changes.
  final List<Song> songs;

  Future<void> _create(BuildContext context) async {
    final name = await askText(context, 'New playlist');
    if (name != null && name.isNotEmpty) {
      await app.db.createPlaylist(name);
    }
  }

  Widget _tile(
    BuildContext context, {
    IconData? icon,
    Widget? art,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: art ??
              ClipPath(
                clipper: const CookieClipper(),
                child: Container(
                  width: 44,
                  height: 44,
                  color: scheme.primaryContainer,
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
              ),
          title: Text(title),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  Future<void> _deleteTopic(BuildContext context, ForumTopic t) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      'Delete ${topicName(t)}?',
      "Its songs move to General first, one at a time, then the topic is deleted in Telegram. "
          "Playlists and favorites keep them. Filing won't make this topic again.",
      'Delete topic',
    );
    if (!ok) return;
    messenger.showSnackBar(SnackBar(content: Text('Moving the songs out of ${topicName(t)}…')));
    final problem = await app.deleteTopicKeepSongs(t);
    messenger.showSnackBar(SnackBar(content: Text(problem ?? 'Deleted ${topicName(t)}. Its songs are in General.')));
  }

  void _openSmart(BuildContext context, String title, Stream<List<Song>> stream) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => smartList(title, stream)),
      );

  Future<void> _import(BuildContext context) async {
    final link = await askText(
      context,
      'Import from Spotify',
      label: 'Playlist link',
      hint: 'Paste the link here',
      paste: true,
    );
    if (link != null && link.isNotEmpty && context.mounted) await runImport(context, link);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Playlist>>(
        stream: app.db.watchPlaylists(),
        builder: (context, snap) {
          final lists = snap.data ?? const <Playlist>[];
          return ListView(
            padding: EdgeInsets.only(top: 4, bottom: MediaQuery.paddingOf(context).bottom + 8),
            children: [
              _tile(
                context,
                icon: Icons.favorite_rounded,
                title: 'Favorites',
                onTap: () => _openSmart(context, 'Favorites', app.db.watchFavorites()),
              ),
              _tile(
                context,
                icon: Icons.history_rounded,
                title: 'Recently played',
                onTap: () => _openSmart(context, 'Recently played', app.db.watchRecent()),
              ),
              _tile(
                context,
                icon: Icons.add_rounded,
                title: 'New playlist',
                onTap: () => _create(context),
              ),
              _tile(
                context,
                icon: Icons.link_rounded,
                title: 'Import from Spotify link',
                onTap: () => _import(context),
              ),
              if (lists.isNotEmpty) const _Heading('Your playlists'),
              for (final l in lists)
                _tile(
                  context,
                  art: PlaylistArt(playlistId: l.id, size: 48),
                  title: l.name,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlist: l)),
                  ),
                ),
              StreamBuilder<List<ForumTopic>>(
                stream: app.db.watchTopics(),
                builder: (context, topics) => Column(
                  children: [
                    if (mainChatTopics(topics.data).isNotEmpty) const _Heading('Telegram topics'),
                    for (final t in mainChatTopics(topics.data))
                      _tile(
                        context,
                        art: TopicArt(topic: t, size: 48),
                        title: topicName(t),
                        onTap: () => _openSmart(context, topicName(t), app.db.watchTopicSongs(t.chatId, t.topicId)),
                        trailing: t.topicId == generalTopicId
                            ? null
                            : PopupMenuButton<void>(
                                tooltip: 'Topic options',
                                onSelected: (_) => _deleteTopic(context, t),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: null, child: Text('Delete topic, keep songs')),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
}

enum _Sort { custom, newest, oldest, title, artist }

final _playlistSort = ValueNotifier(_Sort.custom);

Future<void> loadPlaylistSort() async {
  final name = await app.db.pref('sort_playlist');
  _playlistSort.value = _Sort.values.where((s) => s.name == name).firstOrNull ?? _Sort.custom;
  _playlistSort.addListener(() => app.db.setPref('sort_playlist', _playlistSort.value.name));
}

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key, required this.playlist});
  final Playlist playlist;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Playlist get playlist => widget.playlist;
  _Sort get _sort => _playlistSort.value;

  List<Song> _sorted(List<Song> songs, Map<String, int> dates) {
    int date(Song s) => dates['${s.chatId}:${s.messageId}'] ?? 0;
    return switch (_sort) {
      _Sort.custom => songs,
      _Sort.newest => [...songs]..sort((a, b) => date(b).compareTo(date(a))),
      _Sort.oldest => [...songs]..sort((a, b) => date(a).compareTo(date(b))),
      _Sort.title => [...songs]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
      _Sort.artist => [...songs]..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase())),
    };
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      'Delete "${playlist.name}"?',
      'Songs stay in your library and in Telegram.',
      'Delete',
    );
    if (!ok) return;
    await app.db.deletePlaylist(playlist.id);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Song>>(
        stream: app.db.watchPlaylistSongs(playlist.id),
        builder: (context, snap) => FutureBuilder<Map<String, int>>(
        future: app.db.sourceDates(playlist.id),
        builder: (context, dates) {
          final songs = _sorted(snap.data ?? const <Song>[], dates.data ?? const {});
          final hasDates = (dates.data ?? const {}).isNotEmpty;
          final allPinned = songs.isNotEmpty && songs.every((s) => s.pinned);
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  tooltip: allPinned ? 'Unpin playlist' : 'Pin playlist for offline',
                  isSelected: allPinned,
                  icon: const Icon(Icons.push_pin_outlined),
                  selectedIcon: const Icon(Icons.push_pin_rounded),
                  onPressed: () async {
                    for (final s in songs) {
                      await app.cache.setPinned(s, !allPinned);
                    }
                  },
                ),
                PopupMenuButton<_Sort>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort_rounded),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _playlistSort.value = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _Sort.custom, child: Text('Playlist order')),
                    if (hasDates) ...const [
                      PopupMenuItem(value: _Sort.newest, child: Text('Date added (newest)')),
                      PopupMenuItem(value: _Sort.oldest, child: Text('Date added (oldest)')),
                    ],
                    const PopupMenuItem(value: _Sort.title, child: Text('Title')),
                    const PopupMenuItem(value: _Sort.artist, child: Text('Artist')),
                  ],
                ),
                if (playlist.sourceUrl != null)
                  IconButton(
                    tooltip: 'Refresh from Spotify (also fetches added dates)',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => runImport(context, playlist.sourceUrl!),
                  ),
                IconButton(
                  tooltip: 'Delete playlist',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: SongList(
                    songs: songs,
                    playlistId: playlist.id,
                    header: Column(
                      children: [
                        CollectionHeader(
                          title: playlist.name,
                          songs: songs,
                          art: (size) => PlaylistArt(playlistId: playlist.id, size: size, radius: 12),
                        ),
                        _MissingBanner(playlist: playlist),
                        if (songs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Add songs from their menu.'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SafeArea(top: false, child: MiniPlayer()),
              ],
            ),
          );
        },
        ),
      );
}

/// Shows how many tracks of an imported playlist aren't in the library yet.
class _MissingBanner extends StatelessWidget {
  const _MissingBanner({required this.playlist});
  final Playlist playlist;

  void _show(BuildContext context, List<MissingTrack> tracks) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * 0.7,
            child: Column(
              children: [
                ListTile(
                  title: Row(children: [Flexible(child: Text('${tracks.length} not in your library')), const SizedBox(width: 4), InfoText("They get added here once a matching song shows up in a channel. Tap one to open it in Spotify. Find links makes a temporary list with Spotify and Apple Music links for all of them, to open, copy or save.")]),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Export',
                    icon: const Icon(Icons.ios_share_rounded),
                    onSelected: (v) {
                      Navigator.pop(sheet);
                      if (v == 'find') {
                        exportMissingAsList(context, playlist.name, tracks);
                      } else {
                        pushPage(context, const ExportListsScreen());
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'find', child: Text('Find links as a temporary list')),
                      PopupMenuItem(value: 'lists', child: Text('Temporary lists')),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Map<String, List<Song>>>(
                    future: reviewCandidates(app.db, tracks),
                    builder: (context, snap) {
                      final maybe = snap.data ?? const <String, List<Song>>{};
                      return ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, i) {
                          final t = tracks[i];
                          final guess = maybe[t.trackKey]?.firstOrNull;
                          return ListTile(
                            leading: Icon(guess == null ? Icons.music_off_rounded : Icons.help_outline_rounded),
                            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              guess == null ? t.artist : 'Maybe: ${guess.title} · ${guess.artist} (${guess.durationSec}s, wanted ${t.durationSec}s)',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: guess == null
                                ? null
                                : TextButton(onPressed: () => acceptMatch(app.db, t, guess), child: const Text('Add')),
                            onTap: () => launchUrl(
                              Uri.parse('https://open.spotify.com/track/${t.trackKey.split(':').last}'),
                              mode: LaunchMode.externalApplication,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<MissingTrack>>(
        stream: app.db.watchMissing(playlist.id),
        builder: (context, snap) {
          final tracks = snap.data ?? const <MissingTrack>[];
          if (tracks.isEmpty) return const SizedBox.shrink();
          return ListTile(
            leading: const Icon(Icons.music_off_rounded),
            title: Text('${tracks.length} not in your library yet'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _show(context, tracks),
          );
        },
      );
}

/// Only the main chat's topics. Other channels are only a source of songs, and theirs
/// empty out as songs are copied into the main chat.
List<ForumTopic> mainChatTopics(List<ForumTopic>? topics) {
  final main = app.mainChat.value;
  return [for (final t in topics ?? const <ForumTopic>[]) if (main == null || t.chatId == main) t];
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
